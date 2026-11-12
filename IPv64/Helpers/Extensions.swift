//
//  Extensions.swift
//  IPv64
//
//  Created by Sebastian Rank on 20.10.25.
//

import Foundation
import SwiftUI

extension View {
    func showLoading(_ showLoading: Binding<Bool>) -> some View {
        modifier(LoadingViewModifier(showLoading: showLoading))
    }
    
    @available(iOS 26, *)
    func setColorGradient(_ color: Color) -> some View {
        modifier(ColorGradientModifier(color: color))
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        condition ? AnyView(transform(self)) : AnyView(self)
    }
}

extension UIDevice {
    static var idiom: UIUserInterfaceIdiom {
        UIDevice.current.userInterfaceIdiom
    }
    static var isIpad: Bool {
        idiom == .pad
    }
    
    static var isiPhone: Bool {
        idiom == .phone
    }
}

extension SettingsView {
    func performLogout() -> Bool {
        let user = User.empty
        
        if (user.list.count == 1 || user.list.isEmpty) {
            UserStorage.shared.clear()
        } else {
            user.delete()
        }
        return true
    }
}

extension Sequence {
    func sorted(by keyPath: KeyPath<Element, String>) -> [Element] {
        sorted { ($0[keyPath: keyPath]).lowercased() < ($1[keyPath: keyPath]).lowercased() }
    }
}

extension String {
    func v64domains() -> [String] {
        return [
            "ipv64.net",
            "ipv64.de",
            "any64.de",
            "api64.de",
            "dns64.de",
            "dyndns64.de",
            "eth64.de",
            "dynipv6.de",
            "home64.de",
            "iot64.de",
            "lan64.de",
            "nas64.de",
            "root64.de",
            "route64.de",
            "srv64.de",
            "tcp64.de",
            "udp64.de",
            "vpn64.de",
            "wan64.de",
            "Own Domain"
        ]
    }
    
    func v64DnsRecordTypes() -> [String] {
        return [
            "A",
            "AAAA",
            "TXT",
            "MX",
            "NS",
            "SRV",
            "CNAME",
            "TLSA",
            "CAA"
        ]
    }
    
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
}

extension Bundle {
    
    var appName: String {
        return infoDictionary?["CFBundleName"] as! String
    }
    
    var bundleId: String {
        return bundleIdentifier!
    }
    
    var versionNumber: String {
        return infoDictionary?["CFBundleShortVersionString"] as! String
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as! String
    }
    
    var isProduction: Bool {
#if DEBUG
        return false
#else
        guard let path = self.appStoreReceiptURL?.path else {
            return true
        }
        return !path.contains("sandboxReceipt")
#endif
    }
    
    var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
