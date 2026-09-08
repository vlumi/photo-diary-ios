import SwiftUI

/// The map's bottom-right button stack: todo list (with count badge),
/// drop a todo pin at the map centre, centre on the user.
struct MapControlsOverlay: View {
    let todoCount: Int
    let canDropPin: Bool
    let onListPins: () -> Void
    let onDropPin: () -> Void
    let onLocate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onListPins) {
                roundIcon("list.bullet", tint: .secondary)
                    .overlay(alignment: .topTrailing) {
                        if todoCount > 0 {
                            Text("\(todoCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("List todo pins")

            Button(action: onDropPin) {
                roundIcon("mappin.and.ellipse", tint: .orange)
            }
            .buttonStyle(.plain)
            .disabled(!canDropPin)
            .accessibilityLabel("Drop pin at map centre")

            Button(action: onLocate) {
                roundIcon("location.fill", tint: .accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Center on my location")
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }

    private func roundIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.white)
            .padding(12)
            .background(tint)
            .clipShape(Circle())
            .shadow(radius: 3)
    }
}
