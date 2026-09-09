import SwiftUI

/// What a surface asks the pager to show: an ordered set of photos and
/// the one to open on. The calendar passes its whole grid so swiping
/// walks the month; the map passes a pile, or a single photo.
public struct PhotoPagerSelection: Identifiable, Hashable, Sendable {
    public let photos: [Photo]
    public let index: Int

    public var id: String { photos.indices.contains(index) ? photos[index].id : "empty" }

    public init(photos: [Photo], index: Int) {
        self.photos = photos
        self.index = index
    }

    public init(photo: Photo) {
        self.init(photos: [photo], index: 0)
    }
}

/// Full-screen viewer over an ordered set of photos: swipe (or use the
/// chevrons) to move between them, pinch-zoom the current one. Chrome —
/// close, counter, chevrons, Show on map — is owned here; PhotoViewer
/// is just the image + gestures.
public struct PhotoPagerSheet: View {
    private let photos: [Photo]
    private let loader: any ImageLoader
    private let onDismiss: () -> Void
    /// Offered when set and the current photo has coordinates; the map
    /// itself passes nil since it is already there.
    private let onShowOnMap: ((Photo) -> Void)?

    @State private var index: Int

    public init(
        selection: PhotoPagerSelection,
        loader: any ImageLoader,
        onDismiss: @escaping () -> Void,
        onShowOnMap: ((Photo) -> Void)? = nil
    ) {
        self.photos = selection.photos
        self.loader = loader
        self.onDismiss = onDismiss
        self.onShowOnMap = onShowOnMap
        _index = State(initialValue: selection.index)
    }

    private var current: Photo? { photos.indices.contains(index) ? photos[index] : nil }

    public var body: some View {
        ZStack {
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    PhotoPage(photo: photo, loader: loader)
                        .tag(offset)
                }
            }
            .pagerStyle()
            .ignoresSafeArea()

            chrome
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var chrome: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer()
                if photos.count > 1 {
                    Text("\(index + 1) / \(photos.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Close")
            }
            .padding(8)

            Spacer()

            HStack {
                if photos.count > 1 {
                    chevron("chevron.left", enabled: index > 0, label: "Previous photo") {
                        index -= 1
                    }
                }
                Spacer()
                if photos.count > 1 {
                    chevron("chevron.right", enabled: index < photos.count - 1, label: "Next photo")
                    {
                        index += 1
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            HStack {
                if let onShowOnMap, let current, current.location.coordinates != nil {
                    Button {
                        onShowOnMap(current)
                    } label: {
                        Label("Show on map", systemImage: "map")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func chevron(
        _ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

/// One page: loads the display image through the ImageLoader and hands
/// it to PhotoViewer; loading and failure states in place.
private struct PhotoPage: View {
    let photo: Photo
    let loader: any ImageLoader

    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(PlatformImage)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let image):
                PhotoViewer(image: image)
            case .failed(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: photo.id) {
            state = .loading
            do {
                state = .loaded(try await loader.loadImage(from: photo.displayImageURL))
            } catch {
                state = .failed("Couldn't load photo: \(error.localizedDescription)")
            }
        }
    }
}

extension View {
    /// Page-style tab view is iOS-only; macOS (swift test) gets the
    /// default so the file compiles there.
    fileprivate func pagerStyle() -> some View {
        #if os(iOS)
        return self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        return self
        #endif
    }
}
