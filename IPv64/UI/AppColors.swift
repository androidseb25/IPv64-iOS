import SwiftUI

nonisolated extension Color {
    static let ipv64Blue = Color(red: 0x34 / 255, green: 0x78 / 255, blue: 0xF6 / 255)
    static let ipv64Red = Color(red: 0xE4 / 255, green: 0x4B / 255, blue: 0x3B / 255)
    static let ipv64Orange = Color(red: 0xF1 / 255, green: 0x9A / 255, blue: 0x37 / 255)
    static let ipv64Green = Color(red: 0x39 / 255, green: 0xBF / 255, blue: 0x52 / 255)
    static let ipv64Gray = Color(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255)
    static let ipv64Teal = Color(red: 0x32 / 255, green: 0xAD / 255, blue: 0xE6 / 255)
}

#Preview {
    HStack {
        ForEach([Color.ipv64Blue, .ipv64Red, .ipv64Orange, .ipv64Green, .ipv64Gray, .ipv64Teal], id: \.self) {
            $0.frame(width: 40, height: 40)
        }
    }
}
