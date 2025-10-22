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
