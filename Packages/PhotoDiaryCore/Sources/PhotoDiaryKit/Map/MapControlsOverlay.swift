import SwiftUI

struct MapControlsOverlay: View {
    let todoCount: Int
    let isFollowing: Bool
    let onListPins: () -> Void
    let onLocate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            MapRoundButton("list.bullet", tint: .secondary, action: onListPins)
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
                .accessibilityLabel("List todo pins")
                .accessibilityValue(todoCount > 0 ? "\(todoCount)" : "")

            MapRoundButton(
                isFollowing ? "location.fill" : "location", tint: .accentColor, action: onLocate
            )
            .accessibilityLabel("Follow my location")
            .accessibilityValue(isFollowing ? "On" : "Off")
            .accessibilityAddTraits(isFollowing ? .isSelected : [])
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }
}

struct MapRoundButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    init(_ systemName: String, tint: Color, action: @escaping () -> Void) {
        self.systemName = systemName
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(.white)
                .padding(12)
                .background(tint)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
        .buttonStyle(.plain)
    }
}

struct MapTopBanners: View {
    let isRefreshing: Bool
    let locationError: String?
    var locationDenied = false
    var onDismissLocationError: () -> Void = {}
    let notice: MapNotice?
    let onDismissNotice: () -> Void
    var showsPinHint = false
    var onDismissPinHint: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            if isRefreshing {
                ProgressView().progressViewStyle(.linear).padding(.horizontal)
            }
            if let locationError {
                capsule {
                    HStack(spacing: 8) {
                        Text(locationError)
                        if locationDenied { OpenSettingsButton().bold() }
                        DismissButton(action: onDismissLocationError)
                    }
                }
            }
            if let notice {
                dismissible(Text(notice.text), action: onDismissNotice)
            } else if showsPinHint {
                dismissible(
                    Text("Touch and hold the map to pin a place to come back to."),
                    action: onDismissPinHint)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: notice)
        .animation(.easeInOut(duration: 0.2), value: showsPinHint)
    }

    private func dismissible(_ text: Text, action: @escaping () -> Void) -> some View {
        capsule {
            HStack(spacing: 8) {
                text
                DismissButton(action: action)
            }
        }
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

enum MapNotice: Equatable {
    case noLocatedPhotos
    case refreshFailed(String)

    var text: String {
        switch self {
        case .noLocatedPhotos:
            String(
                localized:
                    "No photos with a location here yet. Touch and hold the map to drop a todo pin."
            )
        case .refreshFailed(let detail):
            String(localized: "Couldn't refresh. \(detail)")
        }
    }
}
