//
//  Biometrics.swift
//  IPv64
//
//  Created by Sebastian Rank on 03.11.25.
//

import Foundation
import LocalAuthentication
import Combine

extension Biometrics: @unchecked Sendable {}

class Biometrics: ObservableObject {
    
    @Published var disableFields: Bool = false
    @Published var isAuthenticated: Bool = false
    
    static func GetBiometricSymbol() -> String {
        _ = checkBiometricType()
        if (LAContext().biometryType == .faceID) {
            return "faceid"
        } else if (LAContext().biometryType == .touchID) {
            return "touchid"
        } else {
            return "lock.circle"
        }
    }
    
    static func GetBiometricText() -> String {
        _ = checkBiometricType()
        if (LAContext().biometryType == .faceID) {
            return "FaceID"
        } else if (LAContext().biometryType == .touchID) {
            return "TouchID"
        } else {
            return "PIN"
        }
    }
    
    static func checkBiometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            if #available(iOS 11.0, *) {
                switch context.biometryType {
                case .none:
                    return "No Biometric Authentication"
                case .touchID:
                    return "TouchID"
                case .faceID:
                    return "FaceID"
                case .opticID:
                    return "OpticID"
                @unknown default:
                    return "Unknown Biometric Authentication"
                }
            } else {
                return "TouchID available"
            }
        } else {
            return "No Biometric Authentication"
        }
    }
    
    func tryToAuthenticate(isIntro: Bool = false) {
        let context = LAContext()
        var error: NSError?
        let reason = "Please authenticate to continue with the app."
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("No Biometric Sensor Has Been Detected. This device does not support FaceID/TouchID.")
            self.disableFields = false
            tryToAuthenticatePIN()
            return
        }
        
        context.evaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason, reply: { (success, error) -> Void in
            DispatchQueue.main.async {
                if success {
                    print("FaceID/TouchID. You are a device owner!")
                    self.isAuthenticated = true
                } else {
                    print(error!)
                    // Check if there is an error
                    if let errorObj = error as? LAError {
                        print("Error took place. \(errorObj.localizedDescription)")
                        if errorObj.code == .userFallback {
                            self.tryToAuthenticatePIN()
                        } else {
                            self.isAuthenticated = false
                        }
                    }
                }
            }
        })
    }
    
    func tryToAuthenticatePIN() {
        let context = LAContext()
        var error: NSError?
        let reason = "Please authenticate to continue with the app."
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("No Biometric Sensor Has Been Detected. This device does not support FaceID/TouchID.")
            self.disableFields = false
            return
        }
        
        context.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: reason, reply: { (success, error) -> Void in
            DispatchQueue.main.async {
                if success {
                    print("FaceID/TouchID. You are a device owner!")
                    self.isAuthenticated = true
                } else {
                    print(error!)
                    // Check if there is an error
                    if let errorObj = error as? LAError {
                        print("Error took place. \(errorObj.localizedDescription)")                        
                        self.isAuthenticated = false
                    }
                }
            }
        })
    }
}
