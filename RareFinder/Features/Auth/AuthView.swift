import SwiftUI
import LocalAuthentication

/// Authentication flow supporting Password-based login and OTP-based signup/reset.
struct AuthView: View {
    enum Step { case initial, code }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// `nil` means the screen presents both Login and Signup pickers.
    var fixedMode: AuthService.Mode?

    /// Callback after a successful login/signup. Defaults to dismiss.
    var onAuthenticated: (() -> Void)?

    @State private var mode: AuthService.Mode = .signup
    @State private var step: Step = .initial
    @State private var identifier: String = ""
    @State private var displayName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var code: String = ""
    @State private var isWorking: Bool = false
    @State private var showEmailFields: Bool = false
    @State private var error: String?
    @State private var info: String?
    
    /// Whether to show a 'Close' button when at the initial step.
    private var showCloseButton: Bool
    private var wasSocialSkipped: Bool
    private var customHeader: AnyView?

    init(mode: AuthService.Mode? = nil, skipSocial: Bool = false, showCloseButton: Bool = true, customHeader: AnyView? = nil, onAuthenticated: (() -> Void)? = nil) {
        self.fixedMode = mode
        self.onAuthenticated = onAuthenticated
        self.showCloseButton = showCloseButton
        self.wasSocialSkipped = skipSocial
        self.customHeader = customHeader
        self._mode = State(initialValue: mode ?? .signup)
        // If we have a fixed mode and aren't skipping social, we still start at landing.
        // But if we skip social (onboarding), we show fields immediately.
        self._showEmailFields = State(initialValue: skipSocial)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                if !isEmbedded {
                    if let customHeader {
                        customHeader
                    } else {
                        AuthHeader(mode: mode)
                    }
                }

                if step == .initial && !showEmailFields {
                    landingContent
                }
            }
            .padding(RFSpacing.lg)
        }
        .background(RFColor.surface.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !showEmailFields && step == .initial && showCloseButton {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showEmailFields) {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    AuthHeader(mode: mode)
                    
                    switch step {
                    case .initial:
                        if mode == .login {
                            loginForm
                        } else if mode == .signup {
                            signupForm
                        } else {
                            resetRequestForm
                        }
                    case .code:
                        codeForm
                    }
                    
                    authStatusMessages
                }
                .padding(RFSpacing.lg)
            }
            .navigationTitle(mode == .signup ? "Sign Up" : (mode == .login ? "Log In" : "Reset Password"))
            .background(RFColor.surface.ignoresSafeArea())
            .onDisappear {
                mode = fixedMode ?? .signup
            }
        }
    }

    @ViewBuilder
    private var landingContent: some View {
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            SocialLoginSection(onAuthenticated: finishAuthentication)
            
            HStack(spacing: 16) {
                Rectangle().fill(RFColor.outlineVariant.opacity(0.3)).frame(height: 1)
                Text("OR").font(.system(size: 11, weight: .black)).foregroundStyle(RFColor.onSurfaceVariant.opacity(0.4))
                Rectangle().fill(RFColor.outlineVariant.opacity(0.3)).frame(height: 1)
            }
            .padding(.vertical, RFSpacing.sm)
            
            // Continue with Email Button
            Button {
                withAnimation { showEmailFields = true }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                    Text(mode == .login ? "Log in with Email" : "Sign up with Email")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .background(RFColor.primaryGradient, in: RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous))
            }
            
            AuthFooter(mode: mode) { newMode in
                withAnimation {
                    mode = newMode
                    showEmailFields = true 
                }
            }
            
            authStatusMessages
        }
    }

    @ViewBuilder
    private var authStatusMessages: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("auth_error")
            }
            if let info {
                Text(info)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var isEmbedded: Bool {
        fixedMode != nil
    }

    private var navigationTitle: String {
        if customHeader != nil { return "" }
        if fixedMode != nil {
            return mode == .signup ? "Sign Up" : (mode == .login ? "Log In" : "Reset Password")
        }
        return "Account"
    }

    @ViewBuilder
    private var loginForm: some View {
        VStack(spacing: RFSpacing.md) {
            TextField("Email or Username", text: $identifier)
                .textFieldStyle(.roundedBorder)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("auth_identifier")

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .accessibilityIdentifier("auth_password")

            if isWorking {
                ProgressView()
            } else {
                RFPrimaryButton(
                    title: "Log In",
                    icon: "lock.fill",
                    action: { Task { await performLogin() } }
                )
                .accessibilityIdentifier("auth_submit_login")

                Button("Forgot Password?") {
                    withAnimation {
                        mode = .resetPassword
                        resetFlow()
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(RFColor.primary)
            }
        }
    }


    @ViewBuilder
    private var signupForm: some View {
        VStack(spacing: RFSpacing.md) {
            TextField("Display name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .accessibilityIdentifier("auth_display_name")

            TextField("Email", text: $identifier)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("auth_email")

            SecureField("Password (min 8 chars)", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .accessibilityIdentifier("auth_password")

            if isWorking {
                ProgressView()
            } else {
                RFPrimaryButton(
                    title: "Send Sign-Up Code",
                    icon: "paperplane.fill",
                    action: { Task { await requestOTP() } }
                )
                .accessibilityIdentifier("auth_send_signup_otp")
            }
        }
    }

    @ViewBuilder
    private var resetRequestForm: some View {
        VStack(spacing: RFSpacing.md) {
            TextField("Email", text: $identifier)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("auth_reset_email")

            if isWorking {
                ProgressView()
            } else {
                RFPrimaryButton(
                    title: "Send Reset Code",
                    icon: "paperplane.fill",
                    action: { Task { await requestOTP() } }
                )
                .accessibilityIdentifier("auth_send_reset_otp")
            }
        }
    }

    @ViewBuilder
    private var codeForm: some View {
        VStack(spacing: RFSpacing.md) {
            Text("Code sent to \(identifier).")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RFColor.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("6-digit code", text: $code)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .accessibilityIdentifier("auth_code")

            if mode == .resetPassword {
                SecureField("New Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    .accessibilityIdentifier("auth_new_password")
            }

            if isWorking {
                ProgressView()
            } else {
                RFPrimaryButton(
                    title: mode == .signup ? "Create Account" : "Reset Password",
                    icon: "checkmark.circle.fill",
                    action: { Task { await submitWithCode() } }
                )
                .accessibilityIdentifier("auth_submit_code")
            }

            Button("Resend code") {
                Task { await requestOTP() }
            }
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(RFColor.primary)
        }
    }

    private func resetFlow() {
        step = .initial
        code = ""
        password = ""
        confirmPassword = ""
        error = nil
        info = nil
    }

    private func requestOTP() async {
        error = nil
        info = nil
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await appState.auth.requestOTP(identifier: identifier, mode: mode)
            info = "Code sent. Check your notifications."
            withAnimation { step = .code }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func performLogin() async {
        error = nil
        info = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.auth.login(identifier: identifier, password: password)
            await finishAuthentication()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submitWithCode() async {
        error = nil
        info = nil
        isWorking = true
        defer { isWorking = false }
        do {
            if mode == .signup {
                try await appState.auth.signup(email: identifier, password: password, code: code, displayName: displayName)
                await finishAuthentication()
            } else if mode == .resetPassword {
                try await appState.auth.resetPassword(email: identifier, code: code, newPassword: password)
                info = "Password reset successful. You can now log in."
                withAnimation {
                    mode = .login
                    resetFlow()
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func finishAuthentication() async {
        if let cb = onAuthenticated { cb() } else { dismiss() }
    }
}

// MARK: - Subviews

struct AuthHeader: View {
    let mode: AuthService.Mode
    
    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Eyebrow(text: eyebrow, color: RFColor.primary)
            Text(title)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(RFColor.onSurface)
            Text(subtitle)
                .font(.rfBody())
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
        }
    }
    
    private var eyebrow: String {
        switch mode {
        case .signup: return "Join The Grid"
        case .login: return "Welcome Back"
        case .resetPassword: return "Security"
        }
    }

    private var title: String {
        switch mode {
        case .signup: return "Create your hunter ID"
        case .login: return "Authenticate to sync"
        case .resetPassword: return "Reset Password"
        }
    }

    private var subtitle: String {
        switch mode {
        case .signup: return "Enter your details. We'll verify your email with a one-time code."
        case .login: return "Enter your credentials to access your profile."
        case .resetPassword: return "Enter your email to receive a reset code."
        }
    }
}

struct SocialLoginSection: View {
    @Environment(AppState.self) private var appState
    var onAuthenticated: () async -> Void
    @State private var error: String?

    var body: some View {
        VStack(spacing: RFSpacing.md) {
            if appState.auth.canUseBiometrics && appState.auth.biometricsEnabled {
                Button {
                    Task {
                        do {
                            try await appState.auth.authenticateWithBiometrics()
                            await onAuthenticated()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: appState.auth.biometricType == .faceID ? "faceid" : "touchid")
                            .font(.system(size: 20))
                        Text("Sign in with \(appState.auth.biometricType == .faceID ? "FaceID" : "TouchID")")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(.white)
                    .background(RFColor.primaryGradient, in: RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous))
                }
            }

            Button {
                Task {
                    do {
                        try await appState.auth.loginWithApple()
                        await onAuthenticated()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20))
                    Text("Continue with Apple")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .background(RFColor.onSurface, in: RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous))
            }

            Button {
                Task {
                    do {
                        try await appState.auth.loginWithApple()
                        await onAuthenticated()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.6))
                    Text("Continue with Google")
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(RFColor.onSurface)
                .background(
                    RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RFRadius.md, style: .continuous)
                        .stroke(RFColor.outlineVariant.opacity(0.3), lineWidth: 1)
                )
            }
            
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
        }
    }
}

struct AuthFooter: View {
    let mode: AuthService.Mode
    var onToggle: (AuthService.Mode) -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Text(mode == .login ? "New here?" : "Already have an account?")
                .foregroundStyle(RFColor.onSurfaceVariant)
            Button(mode == .login ? "Sign Up" : "Log In") {
                onToggle(mode == .login ? .signup : .login)
            }
            .foregroundStyle(RFColor.primary)
            .fontWeight(.bold)
            .accessibilityIdentifier(mode == .login ? "auth_switch_to_signup" : "auth_switch_to_login")
            Spacer()
        }
        .font(.system(size: 14))
        .padding(.top, RFSpacing.sm)
    }
}

#Preview {
    NavigationStack {
        AuthView()
            .environment(AppState())
    }
}
