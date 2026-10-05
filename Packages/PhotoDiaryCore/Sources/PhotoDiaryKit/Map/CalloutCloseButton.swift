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
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(x: 14, y: -14)
        .accessibilityLabel("Close")
    }
}
