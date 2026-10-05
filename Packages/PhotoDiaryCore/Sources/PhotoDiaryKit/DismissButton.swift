import SwiftUI

/// A small × with a finger-sized target that doesn't grow the banner
/// it sits in.
struct DismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(14)
                .contentShape(Rectangle())
                .padding(-14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
    }
}
