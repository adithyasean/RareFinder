import Foundation
import Observation
import LocalAuthentication

/// OTP-based authentication. The backend returns the OTP in the
/// /auth/request-otp response so the iOS client can immediately schedule
/// a local notification surfacing the code — no email server needed for
/// the demo flow.
@Observable
@MainActor
final class AuthService {
    enum Mode: String { case login, signup, resetPassword }

    struct Session: Codable, Equatable {
        var token: String
        var hunterId: UUID
        var displayName: String
        var handle: String
        var email: String?
    }

    enum AuthError: LocalizedError {
        case invalidIdentifier
        case invalidCode
        case biometricNotAvailable
        case biometricFailed
        case backend(String)

        var errorDescription: String? {
            switch self {
            case .invalidIdentifier: return "Enter a valid email or username."
            case .invalidCode: return "Invalid or expired code."
            case .biometricNotAvailable: return "Biometric authentication is not available on this device."
            case .biometricFailed: return "Biometric authentication failed."
            case .backend(let m): return m
            }
        }
    }

    private let tokenKey = "rf.authToken"
    private let sessionKey = "rf.authSession"
    private let biometricsEnabledKey = "rf.biometricsEnabled"

    private(set) var session: Session?
    private(set) var pendingOTP: String?
    private(set) var lastIssuedEmail: String?
    private(set) var lastError: String?

    var biometricsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: biometricsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: biometricsEnabledKey) }
    }

    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var isAuthenticated: Bool { session != nil }

    let client: BackendClient
    let notifications: NotificationService

    init(notifications: NotificationService, client: BackendClient? = nil) {
        self.client = client ?? BackendClient()
        self.notifications = notifications
        self.session = Self.loadSession()
    }

    // MARK: - Persistence

    private static func loadSession() -> Session? {
        guard let data = UserDefaults.standard.data(forKey: "rf.authSession") else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private func persist(_ session: Session?) {
        let defaults = UserDefaults.standard
        if let session, let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: sessionKey)
            defaults.set(session.token, forKey: tokenKey)
        } else {
            defaults.removeObject(forKey: sessionKey)
            defaults.removeObject(forKey: tokenKey)
        }
    }

    // MARK: - Public API

    /// Requests an OTP code from the backend and surfaces it as a local
    /// notification so the user can grab it quickly.
    func requestOTP(identifier: String, mode: Mode) async throws -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Relaxed validation: check if it's an email OR a handle
        let isEmail = trimmed.contains("@") && trimmed.contains(".")
        let isHandle = trimmed.count >= 3 // Basic sanity check
        
        guard isEmail || isHandle else {
            throw AuthError.invalidIdentifier
        }
        
        do {
            let purpose = mode == .resetPassword ? "reset_password" : mode.rawValue
            let response = try await client.requestOTP(identifier: trimmed, purpose: purpose)
            pendingOTP = response.code
            lastIssuedEmail = response.email
            await notifications.scheduleLocalOTP(code: response.code, email: response.email, mode: mode)
            return response.code
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func login(identifier: String, password: String) async throws {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response = try await client.login(identifier: trimmed, password: password)
        let session = Session(
            token: response.token,
            hunterId: response.hunter.id,
            displayName: response.hunter.display_name,
            handle: response.hunter.handle,
            email: response.hunter.email
        )
        self.session = session
        persist(session)
    }

    func signup(email: String, password: String, code: String, displayName: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.signup(
            email: trimmed,
            password: password,
            code: cleanCode,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let session = Session(
            token: response.token,
            hunterId: response.hunter.id,
            displayName: response.hunter.display_name,
            handle: response.hunter.handle,
            email: response.hunter.email
        )
        self.session = session
        persist(session)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.resetPassword(email: trimmed, code: cleanCode, newPassword: newPassword)
    }

    func logout() async {
        if let token = session?.token {
            _ = try? await client.logout(token: token)
        }
        session = nil
        pendingOTP = nil
        persist(nil)
    }

    /// Mock Apple Login for the coursework demo.
    /// In a real app, this would use ASAuthorizationAppleIDProvider.
    func loginWithApple() async throws {
        // For the demo, we'll log in as the default 'Adithya' account.
        // This ensures the user can see moderator features as requested.
        try await login(identifier: "adithya", password: "password123")
    }

    /// Authenticates using FaceID or TouchID. This doesn't hit the backend,
    /// it just unlocks the already-persisted session tokens.
    func authenticateWithBiometrics() async throws {
        guard canUseBiometrics else {
            throw AuthError.biometricNotAvailable
        }
        
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access your hunter profile."
            )
            if !success { throw AuthError.biometricFailed }
            
            // Reload the session to ensure UI updates.
            self.session = Self.loadSession()
        } catch {
            throw AuthError.biometricFailed
        }
    }
}

extension NotificationService {
    /// Schedules a local notification carrying the fresh OTP. The body is
    /// kept short so the lock-screen banner shows the code in full.
    func scheduleLocalOTP(code: String, email: String, mode: AuthService.Mode) async {
        let title: String
        switch mode {
        case .signup: title = "Rare Finder Sign-Up Code"
        case .login: title = "Rare Finder Login Code"
        case .resetPassword: title = "Rare Finder Password Reset"
        }
        let body = "Your code is \(code). Tap to enter it. (Valid 5 min)"
        await scheduleVicinityAlert(title: title, body: body, after: 1)
    }
}
