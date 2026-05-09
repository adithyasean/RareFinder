import Foundation
import Observation

/// OTP-based authentication. The backend returns the OTP in the
/// /auth/request-otp response so the iOS client can immediately schedule
/// a local notification surfacing the code — no email server needed for
/// the demo flow.
@Observable
@MainActor
final class AuthService {
    enum Mode: String { case login, signup }

    struct Session: Codable, Equatable {
        var token: String
        var hunterId: UUID
        var displayName: String
        var handle: String
        var email: String?
    }

    enum AuthError: LocalizedError {
        case invalidEmail
        case invalidCode
        case backend(String)

        var errorDescription: String? {
            switch self {
            case .invalidEmail: return "Enter a valid email."
            case .invalidCode: return "Invalid or expired code."
            case .backend(let m): return m
            }
        }
    }

    private let tokenKey = "rf.authToken"
    private let sessionKey = "rf.authSession"

    private(set) var session: Session?
    private(set) var pendingOTP: String?
    private(set) var lastIssuedEmail: String?
    private(set) var lastError: String?

    var isAuthenticated: Bool { session != nil }

    let client: BackendClient
    let notifications: NotificationService

    init(client: BackendClient = BackendClient(), notifications: NotificationService) {
        self.client = client
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
    func requestOTP(email: String, mode: Mode) async throws -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw AuthError.invalidEmail
        }
        do {
            let response = try await client.requestOTP(email: trimmed, purpose: mode.rawValue)
            pendingOTP = response.code
            lastIssuedEmail = response.email
            await notifications.scheduleLocalOTP(code: response.code, email: response.email, mode: mode)
            return response.code
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func login(email: String, code: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.login(email: trimmed, code: cleanCode)
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

    func signup(email: String, code: String, displayName: String) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.signup(
            email: trimmed,
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

    func logout() async {
        if let token = session?.token {
            _ = try? await client.logout(token: token)
        }
        session = nil
        pendingOTP = nil
        persist(nil)
    }
}

extension NotificationService {
    /// Schedules a local notification carrying the fresh OTP. The body is
    /// kept short so the lock-screen banner shows the code in full.
    func scheduleLocalOTP(code: String, email: String, mode: AuthService.Mode) async {
        let title = mode == .signup ? "Rare Finder Sign-Up Code" : "Rare Finder Login Code"
        let body = "Your code is \(code). Tap to enter it. (Valid 5 min)"
        await scheduleVicinityAlert(title: title, body: body, after: 1)
    }
}
