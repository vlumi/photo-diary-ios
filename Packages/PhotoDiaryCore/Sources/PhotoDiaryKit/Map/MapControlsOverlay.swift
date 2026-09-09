import SwiftUI

/// The map's bottom-right button stack: todo list (with count badge),
/// drop a todo pin at the map center, center on the user.
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
            .accessibilityValue(todoCount > 0 ? "\(todoCount)" : "")

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

/// Top-of-map status: a thin bar while pins refresh, the location
/// error (permission denied, no fix) when there is one, and a notice
/// the user can dismiss — an instance with nothing to pin, or a
/// refresh that failed behind pins already on screen.
struct MapTopBanners: View {
    let isRefreshing: Bool
    let locationError: String?
    let notice: MapNotice?
    let onDismissNotice: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if isRefreshing {
                ProgressView().progressViewStyle(.linear).padding(.horizontal)
            }
            if let locationError {
                capsule { Text(locationError) }
            }
            if let notice {
                capsule {
                    HStack(spacing: 8) {
                        Text(notice.text)
                        Button(action: onDismissNotice) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: notice)
    }

    private func capsule<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// What the map's dismissible banner can say. Reset on every load;
/// dismissed by the user until then.
enum MapNotice: Equatable {
    case noLocatedPhotos
    case refreshFailed(String)

    var text: String {
        switch self {
        case .noLocatedPhotos:
            String(localized: "No photos with a location here yet. Long-press to drop a todo pin.")
        case .refreshFailed(let detail):
            String(localized: "Couldn't refresh. \(detail)")
        }
    }
}
