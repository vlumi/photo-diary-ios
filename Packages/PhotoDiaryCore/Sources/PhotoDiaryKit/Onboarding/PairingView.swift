import SwiftUI

/// Adds a real instance. Three ways in — QR scan, pasted link, or a
/// ticket handed over from a `photodiary://` launch — all converge on
/// the same "Add <host>?" confirmation before anything is consumed,
/// so a mis-scanned or hostile code can't pair silently.
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
                "On the site, open the user menu and choose “Pair a device”. "
                    + "Then scan the code it shows, or paste the link."
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

    private func confirmation(_ ticket: PairingTicket) -> some View {
        Section("Add this instance?") {
            Text(ticket.host)
                .font(.headline)
            Text("The app will sign in to this server with the pairing code.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await pair(ticket) }
            } label: {
                HStack {
                    Text("Add \(ticket.host)")
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
                if QRScannerView.isAvailable {
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
            failure = "That doesn't look like a pairing link."
        }
    }

    private func pair(_ ticket: PairingTicket) async {
        isPairing = true
        failure = nil
        defer { isPairing = false }
        do {
            let instance = try await PairingService(factory: registry.remoteFactory).pair(ticket)
            registry.add(instance)
            registry.setActive(instance.id)
            dismiss()
        } catch let error as PairingError {
            failure = error.errorDescription
        } catch InstanceError.transport(let detail) {
            failure = "Couldn't reach \(ticket.host): \(detail)"
        } catch {
            failure = "Pairing failed: \(error.localizedDescription)"
        }
    }
}

extension View {
    /// A pasted URL wants none of the text-entry conveniences; the
    /// modifiers involved are iOS-only, hence the shim.
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
