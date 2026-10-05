import SwiftUI

/// For when a tap on the map isn't at hand (VoiceOver) or doesn't land
/// where MapKit expects it.
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
