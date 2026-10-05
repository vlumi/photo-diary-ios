import SwiftUI

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Every way in (scan, paste, `photodiary://` launch) ends at the same
/// confirmation before anything is consumed, so a mis-scanned or hostile
/// code can't pair silently.
public struct PairingView: View {
    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.dismiss) private var dismiss

    @State private var ticket: PairingTicket?
    @State private var pasted = ""
    @State private var showScanner = false
    @State private var isPairing = false
    @State private var failure: String?

    public init(initialTicket: PairingTicket? = nil) {
        _ticket = State(initialValue: initialTicket)
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let ticket {
                    confirmation(ticket)
                } else {
                    intake
                }
                if let failure {
                    Section {
                        Text(failure).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add instance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) { scannerSheet }
            .interactiveDismissDisabled(isPairing)
        }
    }

    @ViewBuilder
    private var intake: some View {
        Section {
            Text(
                """
                On the site, open the user menu and choose “Pair a device”. \
                Then scan the code it shows, or paste the link.
                """
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Section {
            Button {
                showScanner = true
            } label: {
                Label("Scan pairing QR code", systemImage: "qrcode.viewfinder")
            }
        }
        Section("Or paste the pairing link") {
            TextField("photodiary://sso?host=…&token=…", text: $pasted)
                .pairingInputStyle()
                .submitLabel(.continue)
                .onSubmit { accept(pasted) }
            HStack {
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { pasted = first }
                }
                .labelStyle(.titleAndIcon)
                Spacer()
                Button("Continue") { accept(pasted) }
                    .disabled(PairingTicket.parse(pasted) == nil)
            }
        }
    }

    /// A code for a server already paired replaces its session, so the
    /// app then sees whatever the code's account sees: said plainly, in
    /// case the link came from someone else.
    private func confirmation(_ ticket: PairingTicket) -> some View {
        let replacing = registry.instances.contains { $0.id == ticket.origin }
        return Section(replacing ? "Replace this pairing?" : "Add this instance?") {
            Text(ticket.origin)
                .font(.headline)
            Text(
                replacing
                    ? "Already paired with this device. Going on signs in as the code's account."
                    : "The app will sign in to this server with the pairing code."
            )
            .font(.footnote)
            .foregroundStyle(replacing ? .orange : .secondary)
            if ticket.scheme == "http" {
                Label(
                    "Unencrypted connection — only for a test instance on your own network.",
                    systemImage: "lock.open"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
            Button {
                Task { await pair(ticket) }
            } label: {
                HStack {
                    Text(
                        registry.instances.contains { $0.id == ticket.origin }
                            ? "Replace pairing with \(ticket.host)" : "Add \(ticket.host)")
                    if isPairing {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isPairing)
            Button("Not this one", role: .cancel) {
                self.ticket = nil
                failure = nil
            }
            .disabled(isPairing)
        }
    }

    @ViewBuilder
    private var scannerSheet: some View {
        NavigationStack {
            Group {
                #if canImport(VisionKit) && os(iOS)
                if Self.cameraRefused {
                    cameraRefusedView
                } else if QRScannerView.isAvailable {
                    QRScannerView { payload in
                        showScanner = false
                        accept(payload)
                    }
                    .ignoresSafeArea()
                } else {
                    scannerUnavailable
                }
                #else
                scannerUnavailable
                #endif
            }
            .navigationTitle("Scan code")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showScanner = false }
                }
            }
        }
    }

    private static var cameraRefused: Bool {
        #if canImport(AVFoundation)
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
        #else
        false
        #endif
    }

    private var cameraRefusedView: some View {
        ContentUnavailableView {
            Label("Camera access is off", systemImage: "camera.badge.ellipsis")
        } description: {
            Text("Allow the camera in Settings to scan the code, or paste the link instead.")
        } actions: {
            OpenSettingsButton()
        }
    }

    private var scannerUnavailable: some View {
        ContentUnavailableView(
            "Camera scanning isn't available here",
            systemImage: "camera.metering.unknown",
            description: Text("Paste the pairing link instead.")
        )
    }

    private func accept(_ text: String) {
        if let parsed = PairingTicket.parse(text) {
            ticket = parsed
            failure = nil
        } else {
            failure = String(localized: "That doesn't look like a pairing link.")
        }
    }

    private func pair(_ ticket: PairingTicket) async {
        isPairing = true
        failure = nil
        defer { isPairing = false }
        do {
            let instance = try await PairingService(factory: registry.remoteFactory).pair(ticket)
            registry.add(instance)
            // Pairing again from inside a gallery stays in that gallery.
            if registry.scope?.instanceId != instance.id {
                registry.enter(Scope(instanceId: instance.id))
            }
            dismiss()
        } catch let error as PairingError {
            failure = error.errorDescription
        } catch InstanceError.transport(let detail) {
            failure = String(localized: "Couldn't reach \(ticket.host): \(detail)")
        } catch {
            failure = String(localized: "Pairing failed: \(error.localizedDescription)")
        }
    }
}

extension View {
    /// The modifiers involved are iOS-only, hence the shim.
    fileprivate func pairingInputStyle() -> some View {
        #if os(iOS)
        return
            self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .font(.footnote.monospaced())
        #else
        return self.font(.footnote.monospaced())
        #endif
    }
}
