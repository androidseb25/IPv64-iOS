import AVKit
import CoreHaptics
import UIKit

public class SoundEffectManager {
  public static let shared: SoundEffectManager = .init()

  public enum SoundEffect: String {
    case pull, refresh
    case tootSent
    case tabSelection
    case bookmark, boost, favorite, share
  }

  private let userPrefs = UserPrefs.shared

  private var currentPlayer: AVAudioPlayer?

  private init() {}

  @MainActor
  public func playSound(of type: SoundEffect) {
    guard userPrefs.soundEffectEnabled else { return }
    if let url = Bundle.main.url(forResource: type.rawValue, withExtension: "wav") {
      try? AVAudioSession.sharedInstance().setCategory(.ambient)
      try? AVAudioSession.sharedInstance().setActive(true)
      currentPlayer = try? .init(contentsOf: url)
      currentPlayer?.prepareToPlay()
      currentPlayer?.play()
    }
  }
}
