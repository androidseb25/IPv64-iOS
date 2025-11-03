//
//  Enum.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import AVFoundation
import SwiftUI

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
    case logout, logoutSuccess, apiError, apiSuccess, apiSuccessDelete, apiSuccessUpdate, updateAlert, deleteDNSAlert, deleteDomainAlert, deleteHc, other
    
    public var id: Int {
        rawValue
    }
    
    public var uuidString: String {
        UUID().uuidString
    }
}

enum Unit: Int, Identifiable {
    case minute, hour, day, unknown
    
    var id: Int {
        switch self {
        case .minute: return 1
        case .hour: return 2
        case .day: return 3
        default: return 0
        }
    }
    
    var label: String {
        switch self {
        case .minute: return "Minute/s"
        case .hour: return "Hour/s"
        case .day: return "Day/s"
        default: return ""
        }
    }
    
    var list: [Unit] {
        [.minute, .hour, .day]
    }
}

enum Status: Int, Identifiable {
    
    case active, pause, warning, alarm, unknown
    
    var id: Int {
        switch self {
        case .active: return 1
        case .pause: return 2
        case .warning: return 3
        case .alarm: return 4
        default: return 0
        }
    }
    
    var label: String {
        switch self {
        case .active: return "Active"
        case .pause: return "Pause"
        case .warning: return "Warning"
        case .alarm: return "Alarm"
        default: return ""
        }
    }
    
    var iconName: String {
        switch self {
        case .active: return "checkmark.circle"
        case .pause: return "pause.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .alarm: return "light.beacon.max.fill"
        default: return ""
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .pause: return .teal
        case .warning: return .orange
        case .alarm: return .red
        case .unknown: return .gray
        }
    }
}
