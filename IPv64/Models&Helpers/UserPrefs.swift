import Combine
import Foundation
import Network
import SwiftUI

@MainActor
public class UserPrefs: ObservableObject {
    
//    public static let groupContainer = "group.sr.angelninde"
//    public static let sharedDefault = UserDefaults(suiteName: groupContainer)
    public static let shared = UserPrefs()
    
    @AppStorage("haptic_tab") public var hapticTabSelectionEnabled = true
    @AppStorage("haptic_timeline") public var hapticTimelineEnabled = true
    @AppStorage("haptic_button_press") public var hapticButtonPressEnabled = true
    @AppStorage("sound_effect_enabled") public var soundEffectEnabled = true
    
}
