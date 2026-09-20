import Foundation

/// The language the app runs in: the device's, or one forced for this
/// app alone. Forcing writes `AppleLanguages` into the app's own
/// defaults, the same place the system's per-app language setting
/// writes, so the two never disagree. The system reads it at launch:
/// strings, date formats and the map's labels all follow, from the
/// next start.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case japanese

    public var id: String { rawValue }

    /// The localization this forces; nil follows the device.
    public var code: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .japanese: "ja"
        }
    }

    /// The language in its own name; nil for `system`, whose label is
    /// a translated word.
    public var nativeName: String? {
        switch self {
        case .system: nil
        case .english: "English"
        case .japanese: "日本語"
        }
    }
}

/// Reads and writes the override. `domain` is the defaults domain the
/// app owns (its bundle id); reading goes through that domain alone,
/// because a plain `array(forKey:)` would fall through to the device's
/// own language list and mistake it for an override.
public struct AppLanguageStore {
    static let key = "AppleLanguages"

    private let defaults: UserDefaults
    private let domain: String

    public init(defaults: UserDefaults = .standard, domain: String) {
        self.defaults = defaults
        self.domain = domain
    }

    public var selection: AppLanguage {
        get {
            let forced = defaults.persistentDomain(forName: domain)?[Self.key] as? [String]
            guard let first = forced?.first else { return .system }
            return AppLanguage.allCases.first { language in
                language.code.map { first == $0 || first.hasPrefix($0 + "-") } ?? false
            } ?? .system
        }
        nonmutating set {
            if let code = newValue.code {
                defaults.set([code], forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }

    /// Whether `selection` would start the app in another localization
    /// than the one it is running in now.
    public static func needsRestart(
        selection: AppLanguage,
        running: String?,
        available: [String],
        devicePreferences: [String]
    ) -> Bool {
        let preferences = selection.code.map { [$0] } ?? devicePreferences
        let next = Bundle.preferredLocalizations(from: available, forPreferences: preferences)
        return next.first != running
    }
}
