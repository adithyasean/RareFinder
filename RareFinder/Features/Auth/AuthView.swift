import SwiftUI

/// Authentication flow supporting Password-based login and OTP-based signup/reset.
struct AuthView: View {
    enum Step { case initial, code }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// `nil` means the screen presents both Login and Signup pickers.
    var fixedMode: AuthService.Mode?

    /// Callback after a successful login/signup. Defaults to dismiss.
    var onAuthenticated: (() -> Void)?

    @State private var mode: AuthService.Mode = .login
    @State private var step: Step = .initial
    @State private var identifier: String = ""
    @State private var displayName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var code: String = ""
    @State private var isWorking: Bool = false
    @State private var error: String?
    @State private var info: String?

    init(mode: AuthService.Mode? = nil, onAuthenticated: (() -> Void)? = nil) {
        self.fixedMode = mode
        self.onAuthenticated = onAuthenticated
        self._mode = State(initialValue: mode ?? .login)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                header

                if fixedMode == nil && step == .initial {
                    Picker("Mode", selection: $mode) {
                        Text("Log In").tag(AuthService.Mode.login)
                        Text("Sign Up").tag(AuthService.Mode.signup)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in resetFlow() }
                }

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
            .padding(RFSpacing.lg)
        }
        .background(RFColor.surface.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if step == .code || mode == .resetPassword {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        if step == .code {
                            step = .initial
                        } else {
                            mode = .login
                            resetFlow()
                        }
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        if fixedMode != nil {
            return mode == .signup ? "Sign Up" : (mode == .login ? "Log In" : "Reset Password")
        }
        return "Account"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Eyebrow(text: headerEyebrow, color: RFColor.primary)
            Text(headerTitle)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(RFColor.onSurface)
            Text(headerSubtitle)
                .font(.rfBody())
                .foregroundStyle(RFColor.onSurfaceVariant.opacity(0.75))
        }
    }

    private var headerEyebrow: String {
        switch mode {
        case .signup: return "Join The Grid"
        case .login: return "Welcome Back"
        case .resetPassword: return "Security"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .signup: return "Create your hunter ID"
        case .login: return "Authenticate to sync"
        case .resetPassword: return "Reset Password"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .signup: return "Enter your details. We'll verify your email with a one-time code."
        case .login: return "Enter your credentials to access your profile."
        case .resetPassword: return "Enter your email to receive a reset code."
        }
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

#Preview {
    NavigationStack {
        AuthView()
            .environment(AppState())
    }
}
