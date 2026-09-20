import Foundation
import Testing

@testable import PhotoDiaryCore

@Suite struct AppLanguageTests {
    /// A throwaway defaults domain, emptied again when the test ends.
    private final class Scratch {
        let suite = "AppLanguageTests." + UUID().uuidString
        let defaults: UserDefaults
        let store: AppLanguageStore

        init() {
            defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            store = AppLanguageStore(defaults: defaults, domain: suite)
        }

        deinit { defaults.removePersistentDomain(forName: suite) }

        var forced: [String]? {
            defaults.persistentDomain(forName: suite)?["AppleLanguages"] as? [String]
        }
    }

    @Test func followsTheDeviceUntilALanguageIsForced() {
        let scratch = Scratch()
        #expect(scratch.store.selection == .system)
    }

    @Test(arguments: [AppLanguage.english, .japanese])
    func forcingWritesTheLanguageListTheSystemReads(language: AppLanguage) {
        let scratch = Scratch()
        scratch.store.selection = language
        #expect(scratch.forced == [language.code!])
        #expect(scratch.store.selection == language)
    }

    @Test func returningToSystemRemovesTheOverride() {
        let scratch = Scratch()
        scratch.store.selection = .japanese
        scratch.store.selection = .system
        #expect(scratch.forced == nil)
        #expect(scratch.store.selection == .system)
    }

    @Test func readsAnOverrideTheSystemSettingWroteWithARegion() {
        let scratch = Scratch()
        scratch.defaults.set(["ja-JP"], forKey: "AppleLanguages")
        #expect(scratch.store.selection == .japanese)
    }

    @Test func aLanguageTheAppDoesNotOfferReadsAsSystem() {
        let scratch = Scratch()
        scratch.defaults.set(["fi"], forKey: "AppleLanguages")
        #expect(scratch.store.selection == .system)
    }

    @Test func aRestartIsNeededOnlyWhenTheLocalizationWouldChange() {
        let available = ["en", "ja"]
        func needs(_ selection: AppLanguage, running: String, device: [String]) -> Bool {
            AppLanguageStore.needsRestart(
                selection: selection, running: running, available: available,
                devicePreferences: device)
        }
        #expect(needs(.japanese, running: "en", device: ["en-JP"]))
        #expect(!needs(.english, running: "en", device: ["ja-JP"]))
        #expect(!needs(.system, running: "ja", device: ["ja-JP", "en-JP"]))
        #expect(needs(.system, running: "ja", device: ["en-JP", "ja-JP"]))
        // A Finnish phone runs the app in English either way.
        #expect(!needs(.system, running: "en", device: ["fi-FI"]))
    }
}
