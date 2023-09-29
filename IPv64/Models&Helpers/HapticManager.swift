import CoreHaptics
import UIKit

public class HapticManager {
  public static let shared: HapticManager = .init()

  public enum HapticType {
    case buttonPress
    case dataRefresh(intensity: CGFloat)
    case notification(_ type: UINotificationFeedbackGenerator.FeedbackType)
    case tabSelection
    case timeline
  }

  private let selectionGenerator = UISelectionFeedbackGenerator()
  private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
  private let notificationGenerator = UINotificationFeedbackGenerator()

  private let userPrefs = UserPrefs.shared

  private init() {
    selectionGenerator.prepare()
    impactGenerator.prepare()
  }

  @MainActor
  public func fireHaptic(of type: HapticType) {
    guard supportsHaptics else { return }

    switch type {
    case .buttonPress:
      if userPrefs.hapticButtonPressEnabled {
        impactGenerator.impactOccurred()
      }
    case let .dataRefresh(intensity):
      if userPrefs.hapticTimelineEnabled {
        impactGenerator.impactOccurred(intensity: intensity)
      }
    case let .notification(type):
      if userPrefs.hapticButtonPressEnabled {
        notificationGenerator.notificationOccurred(type)
      }
    case .tabSelection:
      if userPrefs.hapticTabSelectionEnabled {
        selectionGenerator.selectionChanged()
      }
    case .timeline:
      if userPrefs.hapticTimelineEnabled {
        selectionGenerator.selectionChanged()
      }
    }
  }

  public var supportsHaptics: Bool {
    CHHapticEngine.capabilitiesForHardware().supportsHaptics
  }
}
