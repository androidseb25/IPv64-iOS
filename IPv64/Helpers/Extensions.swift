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

extension DateFormatter {
    static let db: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        condition ? AnyView(transform(self)) : AnyView(self)
    }
}

extension AccountInfo {
    func usageColor(used: Int, max: Int) -> Color {
        // Kein Limit (∞) → grün
        guard max > 0 else {
            return used == 0 ? .red : .green
        }
        
        let ratio = Double(used) / Double(max)
        switch ratio {
        case ..<0.7: return .green
        case ..<0.9: return .yellow
        default:     return .red
        }
    }
    
    func usageText(used: Int, max: Int) -> String {
        let usedStr = used.formatted(.number.grouping(.automatic))
        var maxStr = ""
        
        if (max < used) {
            maxStr = "∞"
        } else {
            maxStr = max.formatted(.number.grouping(.automatic))
        }
        return "\(usedStr) / \(maxStr)"
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

// MARK: - Parser-Helfer

extension IntegrationResult {
    static func parse(jsonData: Data) throws -> IntegrationResult {
        let decoder = JSONDecoder()
        return try decoder.decode(IntegrationResult.self, from: jsonData)
    }
    
    static func parse(jsonString: String) throws -> IntegrationResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "IntegrationResult", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
        }
        return try parse(jsonData: data)
    }
}

// MARK: - Parser-Helfer

extension DomainResult {
    static func parse(jsonData: Data) throws -> DomainResult {
        try JSONDecoder().decode(DomainResult.self, from: jsonData)
    }

    static func parse(jsonString: String) throws -> DomainResult {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "DomainResult", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
        }
        return try parse(jsonData: data)
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
}
