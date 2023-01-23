//
//  Biometrics.swift
//
//
//  Created by Sebastian Rank on 05.04.22.
//

import Foundation
import LocalAuthentication

class Biometrics: ObservableObject {
    
    @Published var isAuthenticated = false
    @Published var disableFields = true
    @Published private(set) var error: Error?
    
    static func GetBiometricSymbol() -> String {
        if (LAContext().biometryType == .faceID) {
            return "faceid"
        } else if (LAContext().biometryType == .touchID) {
            return "touchid"
        } else {
            return "lock.circle"
        }
    }
    
    static func GetBiometricText() -> String {
        if (LAContext().biometryType == .faceID) {
            return "FaceID"
        } else if (LAContext().biometryType == .touchID) {
            return "TouchID"
        } else {
            return "PIN"
        }
    }
    
    func reset() {
        isAuthenticated = false
        disableFields = true
    }
    
    func tryToAuthenticate(isIntro: Bool = false) {
        let context = LAContext()
        var error: NSError?
        let reason = "Bitte authentifiziere dich, um mit der App fortzufahren."
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("No Biometric Sensor Has Been Detected. This device does not support FaceID/TouchID.")
            self.disableFields = false
            tryToAuthenticatePIN()
            return
        }
        
        context.evaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason, reply: { (success, error) -> Void in
            DispatchQueue.main.async {
                self.error = error
                if success {
                    print("FaceID/TouchID. You are a device owner!")
                    self.isAuthenticated = true
                } else {
                    print(error!)
                    // Check if there is an error
                    if let errorObj = error as? LAError {
                        print("Error took place. \(errorObj.localizedDescription)")
                        if errorObj.code == .userCancel {
                            self.isAuthenticated = false
                            self.disableFields = false
                        }
                        if errorObj.code == .userFallback {
                            self.tryToAuthenticatePIN()
                        }
                    }
                }
            }
        })
    }
    
    func tryToAuthenticatePIN() {
        let context = LAContext()
        var error: NSError?
        let reason = "Bitte authentifiziere dich, um mit der App fortzufahren."
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            print("No Biometric Sensor Has Been Detected. This device does not support FaceID/TouchID.")
            self.disableFields = false
            return
        }
        
        context.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: reason, reply: { (success, error) -> Void in
            DispatchQueue.main.async {
                self.error = error
                if success {
                    print("FaceID/TouchID. You are a device owner!")
                    self.isAuthenticated = true
                } else {
                    print(error!)
                    // Check if there is an error
                    if let errorObj = error as? LAError {
                        print("Error took place. \(errorObj.localizedDescription)")
                        if errorObj.code == .userCancel {
                            self.isAuthenticated = false
                            self.disableFields = false
                        }
                        if errorObj.code == .userFallback {
                            self.isAuthenticated = false
                            self.disableFields = false
                        }
                    }
                }
            }
        })
    }
}
