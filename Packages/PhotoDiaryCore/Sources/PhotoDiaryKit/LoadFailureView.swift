import SwiftUI

/// The full-surface failure state every loading screen shows: what
/// failed, the error's own sentence, and a Retry that re-runs the load.
struct LoadFailureView: View {
    let title: LocalizedStringKey
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
