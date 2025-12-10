import Foundation
import Combine

/// App-wide settings for UI preferences
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let showYouTubeVideos = "appSettings.showYouTubeVideos"
        static let showFormTips = "appSettings.showFormTips"
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
    }
}
