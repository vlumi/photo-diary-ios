import PhotoDiaryCore
import SwiftUI

/// Settings and About in one sheet, opened from the front page: the
/// app has one setting, and the rest is what it is and whose.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var language: AppLanguage

    private let store: AppLanguageStore

    init() {
        let store = AppLanguageStore(domain: Bundle.main.bundleIdentifier ?? "")
        self.store = store
        _language = State(initialValue: store.selection)
    }

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                aboutSection
                privacySection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var languageSection: some View {
        Section {
            Picker("Language", selection: $language) {
                ForEach(AppLanguage.allCases) { option in
                    (option.nativeName.map { Text(verbatim: $0) } ?? Text("System")).tag(option)
                }
            }
            .onChange(of: language) { _, chosen in store.selection = chosen }
        } footer: {
            if needsRestart {
                Label("Restart the app to change the language.", systemImage: "arrow.clockwise")
            } else {
                Text("The map's labels follow the language too.")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") { Text(verbatim: Self.versionLine) }
            LabeledContent("Made by") { Text(verbatim: "Ville Misaki") }
            link("Source code", "https://github.com/vlumi/photo-diary-ios")
            link("Photo Diary server", "https://github.com/vlumi/photo-diary")
            link("Images load with Nuke", "https://github.com/kean/Nuke")
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Text(
                """
                The app talks to the sites you pair it with, and to Apple for the map. \
                Nothing is sent to its author or to anyone else.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func link(_ title: LocalizedStringKey, _ address: String) -> some View {
        Link(destination: URL(string: address)!) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var needsRestart: Bool {
        // The device's own list, read past any override the app holds.
        let device =
            UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[
                "AppleLanguages"] as? [String]
        return AppLanguageStore.needsRestart(
            selection: language,
            running: Bundle.main.preferredLocalizations.first,
            available: Bundle.main.localizations,
            devicePreferences: device ?? Locale.preferredLanguages
        )
    }

    /// From the bundle, so it cannot disagree with what shipped.
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }
}
