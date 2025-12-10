import Foundation
import Combine
import AudioToolbox
import UserNotifications

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
        guard let soundID = systemSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - App Settings

/// App-wide settings for UI preferences
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let showYouTubeVideos = "appSettings.showYouTubeVideos"
        static let showFormTips = "appSettings.showFormTips"
        static let restNotificationSound = "appSettings.restNotificationSound"
    }

    // MARK: - Published Properties

    /// Whether to show YouTube video demonstrations in exercise detail sheets
    @Published var showYouTubeVideos: Bool {
        didSet {
            defaults.set(showYouTubeVideos, forKey: Keys.showYouTubeVideos)
        }
    }

    /// Whether to show form tips in exercise detail sheets
    @Published var showFormTips: Bool {
        didSet {
            defaults.set(showFormTips, forKey: Keys.showFormTips)
        }
    }

    /// The sound to play when rest timer completes
    @Published var restNotificationSound: RestNotificationSound {
        didSet {
            defaults.set(restNotificationSound.rawValue, forKey: Keys.restNotificationSound)
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

        self.showYouTubeVideos = defaults.bool(forKey: Keys.showYouTubeVideos)
        self.showFormTips = defaults.bool(forKey: Keys.showFormTips)

        // Load rest notification sound preference
        if let soundRawValue = defaults.string(forKey: Keys.restNotificationSound),
           let sound = RestNotificationSound(rawValue: soundRawValue) {
            self.restNotificationSound = sound
        } else {
            self.restNotificationSound = .default
        }
    }
}
