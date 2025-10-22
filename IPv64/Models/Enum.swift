//
//  Enum.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import AVFoundation

enum CameraPermission {
    case authorized, denied, notDetermined, restricted

    static func status() -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static func request() async -> CameraPermission {
        await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                cont.resume(returning: granted ? .authorized : .denied)
            }
        }
    }
}

enum AlertType: Int, Identifiable {
    case logout, logoutSuccess, other
    
    public var id: Int {
        rawValue
    }
    
    public var uuidString: String {
        UUID().uuidString
    }
}
