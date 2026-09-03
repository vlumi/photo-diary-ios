// Placeholder — the SwiftUI shell, tab bar, Map / Calendar / Photo / Todo
// views land here in follow-up PRs (see ROADMAP.md).
import SwiftUI
import PhotoDiaryCore

public struct PhotoDiaryRootView: View {
    public init() {}
    public var body: some View {
        VStack {
            Text("Photo Diary companion — scaffold \(PhotoDiaryCore.scaffoldVersion)")
                .font(.headline)
            Text("See ROADMAP.md for what lands next.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
