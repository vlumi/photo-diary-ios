import SwiftUI

/// The × in a callout's corner: closing by a plain button, for when a
/// tap on the map is not at hand (VoiceOver, a crowded screen) or does
/// not land where MapKit expects it.
struct CalloutCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .gray)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 8, y: -8)
        .accessibilityLabel("Close")
    }
}
