import LocalAuthentication

/// Android BiometricPromptManager (spec 01 §3b): device owner authentication (biometrics or passcode).
enum Biometrics {
    /// `true` unlocks. Missing passcode / no enrolled biometrics / no hardware also unlock
    /// ("do not lock out permanently"); cancel or failure keeps the app locked.
    static func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return unlocksWithoutPrompt(error.map { LAError.Code(rawValue: $0.code) } ?? nil)
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Please authenticate to continue"))
        } catch let error as LAError {
            return unlocksWithoutPrompt(error.code)
        } catch {
            return false
        }
    }

    private static func unlocksWithoutPrompt(_ code: LAError.Code?) -> Bool {
        switch code {
        case .passcodeNotSet, .biometryNotEnrolled, .biometryNotAvailable: true
        default: false
        }
    }

    /// SF Symbol for the lock screen and the Lockscreen setting row.
    static var symbol: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .opticID: return "opticid"
        case .touchID: return "touchid"
        default: return "lock"
        }
    }
}
