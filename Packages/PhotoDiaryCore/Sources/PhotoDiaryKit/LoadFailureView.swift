import SwiftUI

/// What a screen keeps when its load fails: the error's sentence, and
/// whether it was the session being rejected, which gets its own state.
struct LoadFailure: Equatable {
    let message: String
    let sessionExpired: Bool

    init(_ error: any Error) {
        message = error.localizedDescription
        if case InstanceError.sessionExpired = error {
            sessionExpired = true
        } else {
            sessionExpired = false
        }
    }

    init(message: String) {
        self.message = message
        sessionExpired = false
    }
}

/// The full-surface failure state every loading screen shows: what
/// failed, the error's own sentence, and a Retry that re-runs the load.
/// A rejected session shows "Pair again" instead, opening the pairing
/// sheet; dismissing it retries, so a successful re-pair reloads in
/// place.
struct LoadFailureView: View {
    let title: LocalizedStringKey
    let failure: LoadFailure
    let retry: () -> Void

    @Environment(InstanceRegistry.self) private var registry
    @State private var showPairing = false

    var body: some View {
        if failure.sessionExpired {
            ContentUnavailableView {
                Label("Session expired", systemImage: "person.crop.circle.badge.exclamationmark")
            } description: {
                expiredMessage
            } actions: {
                Button("Pair again") { showPairing = true }
                    .buttonStyle(.borderedProminent)
                // The site's "Pair a device" page hands the ticket back
                // through its "Open in app" link, so this round-trips.
                if let site = siteURL {
                    Link("Open the site to sign in", destination: site)
                }
            }
            .sheet(isPresented: $showPairing, onDismiss: retry) {
                PairingView().environment(registry)
            }
        } else {
            ContentUnavailableView {
                Label(title, systemImage: "exclamationmark.triangle")
            } description: {
                Text(failure.message)
            } actions: {
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var siteURL: URL? {
        guard let instance = registry.activeInstance, !instance.isDemo else { return nil }
        return URL(string: instance.id)
    }

    private var expiredMessage: Text {
        let name = registry.activeInstance?.displayName ?? String(localized: "this instance")
        return Text("Your pairing with \(name) has expired. Pair this device again.")
    }
}
