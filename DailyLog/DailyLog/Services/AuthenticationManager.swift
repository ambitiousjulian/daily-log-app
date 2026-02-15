import LocalAuthentication
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isUnlocked = false
    @Published var isAuthenticating = false
    @Published var authError: String?

    private var hasBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check if biometrics is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics available (e.g., simulator) — unlock automatically
            isUnlocked = true
            return
        }

        isAuthenticating = true
        authError = nil

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock DailyLog to access your entries"
        ) { success, authenticationError in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                if success {
                    self.isUnlocked = true
                    self.authError = nil
                } else {
                    self.authError = authenticationError?.localizedDescription ?? "Authentication failed"
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
        authError = nil
    }
}
