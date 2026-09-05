import SwiftUI
import PhotoDiaryKit

@main
struct PhotoDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            // App shell + tab bar land in a later commit on this branch.
            // For now the entry point just renders a placeholder so the
            // target compiles and the simulator has something to show.
            Text("Photo Diary — foundation build")
                .font(.headline)
                .padding()
        }
    }
}
