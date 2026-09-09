import SwiftUI

/// The map's bottom-right button stack: todo list (with count badge),
/// drop a todo pin at the map centre, centre on the user.
struct MapControlsOverlay: View {
    let todoCount: Int
    let onListPins: () -> Void
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

/// Top-of-map status: a thin bar while pins refresh, and the location
/// error (permission denied, no fix) when there is one.
struct MapTopBanners: View {
    let isRefreshing: Bool
    let locationError: String?

    var body: some View {
        VStack(spacing: 6) {
            if isRefreshing {
                ProgressView().progressViewStyle(.linear).padding(.horizontal)
            }
            if let locationError {
                Text(locationError)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
