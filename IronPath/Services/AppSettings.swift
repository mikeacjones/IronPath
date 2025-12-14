import Foundation
import AudioToolbox
import UserNotifications
import AVFoundation
import OSLog

// MARK: - Rest Notification Sound

/// Available notification sounds for rest timer completion
enum RestNotificationSound: String, CaseIterable, Codable {
    case `default` = "default"
    case tritone = "tri-tone"
    case note = "note"
    case aurora = "aurora"
    case bamboo = "bamboo"
    case chord = "chord"
    case circles = "circles"
    case complete = "complete"
    case hello = "hello"
    case input = "input"
    case keys = "keys"
    case popcorn = "popcorn"
    case pulse = "pulse"
    case synth = "synth"
    case none = "none"

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .tritone: return "Tri-tone"
        case .note: return "Note"
        case .aurora: return "Aurora"
        case .bamboo: return "Bamboo"
        case .chord: return "Chord"
        case .circles: return "Circles"
        case .complete: return "Complete"
        case .hello: return "Hello"
        case .input: return "Input"
        case .keys: return "Keys"
        case .popcorn: return "Popcorn"
        case .pulse: return "Pulse"
        case .synth: return "Synth"
        case .none: return "None"
        }
    }

    /// The notification sound for background notifications
    var notificationSound: UNNotificationSound? {
        switch self {
        case .none:
            return nil
        case .default:
            return .default
        default:
            // iOS system sounds are available as notification sounds
            return .default
        }
    }

    /// System sound ID for foreground playback using AudioToolbox
    /// These are standard iOS system sound IDs
    var systemSoundID: SystemSoundID? {
        switch self {
        case .none:
            return nil
        case .default:
            return 1007 // Default notification sound
        case .tritone:
            return 1002 // Tri-tone
        case .note:
            return 1013 // Tweet
        case .aurora:
            return 1030 // Aurora
        case .bamboo:
            return 1031 // Bamboo
        case .chord:
            return 1032 // Chord
        case .circles:
            return 1033 // Circles
        case .complete:
            return 1034 // Complete
        case .hello:
            return 1035 // Hello
        case .input:
            return 1036 // Input
        case .keys:
            return 1037 // Keys
        case .popcorn:
            return 1038 // Popcorn
        case .pulse:
            return 1039 // Pulse
        case .synth:
            return 1040 // Synth
        }
    }

    /// Play this sound immediately (for preview or foreground playback)
    func playSound() {
        // Use configurable volume via SoundPlayer
        SoundPlayer.shared.playSound(self)
    }
}

// MARK: - Sound Player

/// Singleton to manage sound playback with volume control
class SoundPlayer: NSObject {
    static let shared = SoundPlayer()

    private var audioPlayer: AVAudioPlayer?
    private var isAudioSessionConfigured = false

    private override init() {
        super.init()
        configureAudioSession()
    }

    /// Configure audio session to play sounds even when silent mode is on
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use playback category to play through silent mode, ambient to mix with others
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isAudioSessionConfigured = true
        } catch {
            AppLogger.settings.error("Failed to configure audio session", error: error)
        }
    }

    /// Play a notification sound at the configured volume
    func playSound(_ sound: RestNotificationSound) {
        guard sound != .none else { return }

        let volume = AppSettings.shared.restNotificationVolume

        // Ensure audio session is active
        if !isAudioSessionConfigured {
            configureAudioSession()
        }

        // Try to play custom sound file first (if bundled)
        if let url = soundFileURL(for: sound) {
            playFromFile(url: url, volume: Float(volume))
            return
        }

        // Fallback to system sound (these don't support volume control, but we'll
        // at least configure the session to play through silent mode)
        // Play multiple times for "louder" effect based on volume setting
        if let soundID = sound.systemSoundID {
            // For high volume settings, trigger vibration as well for attention
            if volume > 0.7 {
                AudioServicesPlayAlertSound(soundID)  // Alert sound includes vibration
            } else {
                AudioServicesPlaySystemSound(soundID)
            }
        }
    }

    /// Get URL for bundled sound file (if exists)
    private func soundFileURL(for sound: RestNotificationSound) -> URL? {
        // Map sound names to potential bundled file names
        let fileName: String
        switch sound {
        case .default: fileName = "notification_default"
        case .tritone: fileName = "tritone"
        case .note: fileName = "note"
        case .aurora: fileName = "aurora"
        case .bamboo: fileName = "bamboo"
        case .chord: fileName = "chord"
        case .circles: fileName = "circles"
        case .complete: fileName = "complete"
        case .hello: fileName = "hello"
        case .input: fileName = "input"
        case .keys: fileName = "keys"
        case .popcorn: fileName = "popcorn"
        case .pulse: fileName = "pulse"
        case .synth: fileName = "synth"
        case .none: return nil
        }

        // Check for bundled audio files (wav, mp3, m4a, aiff, caf)
        for ext in ["wav", "mp3", "m4a", "aiff", "caf"] {
            if let url = Bundle.main.url(forResource: fileName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// Play audio from file with volume control
    private func playFromFile(url: URL, volume: Float) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            AppLogger.settings.warning("Failed to play audio file, falling back to system sound: \(error.localizedDescription)")
            // Fallback to system sound
            AudioServicesPlaySystemSound(1007)
        }
    }
}

// MARK: - App Settings

/// App-wide settings for UI preferences
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let showYouTubeVideos = "appSettings.showYouTubeVideos"
        static let showFormTips = "appSettings.showFormTips"
        static let restNotificationSound = "appSettings.restNotificationSound"
        static let restNotificationVolume = "appSettings.restNotificationVolume"
        static let showAIWorkoutSummary = "appSettings.showAIWorkoutSummary"
    }

    // MARK: - Properties

    /// Whether to show YouTube video demonstrations in exercise detail sheets
    var showYouTubeVideos: Bool {
        didSet {
            defaults.set(showYouTubeVideos, forKey: Keys.showYouTubeVideos)
        }
    }

    /// Whether to show form tips in exercise detail sheets
    var showFormTips: Bool {
        didSet {
            defaults.set(showFormTips, forKey: Keys.showFormTips)
        }
    }

    /// The sound to play when rest timer completes
    var restNotificationSound: RestNotificationSound {
        didSet {
            defaults.set(restNotificationSound.rawValue, forKey: Keys.restNotificationSound)
        }
    }

    /// Volume for rest notification sound (0.0 to 1.0)
    /// Note: Volume control works with custom bundled audio files. System sounds play at device volume.
    var restNotificationVolume: Double {
        didSet {
            defaults.set(restNotificationVolume, forKey: Keys.restNotificationVolume)
        }
    }

    /// Whether to show AI-generated workout summary on completion
    var showAIWorkoutSummary: Bool {
        didSet {
            defaults.set(showAIWorkoutSummary, forKey: Keys.showAIWorkoutSummary)
        }
    }

    // MARK: - Initialization

    private init() {
        // Default to true (show videos and tips) if not previously set
        if defaults.object(forKey: Keys.showYouTubeVideos) == nil {
            defaults.set(true, forKey: Keys.showYouTubeVideos)
        }
        if defaults.object(forKey: Keys.showFormTips) == nil {
            defaults.set(true, forKey: Keys.showFormTips)
        }
        // Default volume to 1.0 (max) if not set
        if defaults.object(forKey: Keys.restNotificationVolume) == nil {
            defaults.set(1.0, forKey: Keys.restNotificationVolume)
        }
        // Default AI workout summary to true
        if defaults.object(forKey: Keys.showAIWorkoutSummary) == nil {
            defaults.set(true, forKey: Keys.showAIWorkoutSummary)
        }

        self.showYouTubeVideos = defaults.bool(forKey: Keys.showYouTubeVideos)
        self.showFormTips = defaults.bool(forKey: Keys.showFormTips)
        self.restNotificationVolume = defaults.double(forKey: Keys.restNotificationVolume)
        self.showAIWorkoutSummary = defaults.bool(forKey: Keys.showAIWorkoutSummary)

        // Load rest notification sound preference
        if let soundRawValue = defaults.string(forKey: Keys.restNotificationSound),
           let sound = RestNotificationSound(rawValue: soundRawValue) {
            self.restNotificationSound = sound
        } else {
            self.restNotificationSound = .default
        }
    }
}
