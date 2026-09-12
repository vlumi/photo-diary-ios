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

/// The viewer, presented as a sheet, over an ordered set of photos:
/// swipe (or use the chevrons) to move between them, pinch-zoom the
/// current one, swipe down to put it away. Chrome — close, counter,
/// chevrons, Show on map — is owned here; PhotoViewer is just the
/// image + gestures.
///
/// Pages live in a paging ScrollView rather than a page-style TabView:
/// the viewer's own drag gesture on each page made the TabView overshoot
/// by a page, and a ScrollView can be told to stop paging while zoomed.
public struct PhotoPagerSheet: View {
    private let photos: [Photo]
    private let loader: any ImageLoader
    private let onDismiss: () -> Void
    /// Offered when set and the current photo has coordinates; the map
    /// itself passes nil since it is already there.
    private let onShowOnMap: ((Photo) -> Void)?

    @State private var currentId: String?
    @State private var zoomed = false
    // A downward drag on the photo pulls the page along and, past the
    // threshold or with a flick, puts the viewer away. The sheet's own
    // dismiss only takes drags from its top edge; the pager's scroll
    // view claims the rest, so PullDownRecognizer is what makes "swipe
    // down" work where the finger naturally is.
    @State private var pullDown: CGFloat = 0

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
        let photos = selection.photos
        _currentId = State(
            initialValue: photos.indices.contains(selection.index)
                ? photos[selection.index].id : photos.first?.id)
    }

    private var index: Int { photos.firstIndex { $0.id == currentId } ?? 0 }
    private var current: Photo? { photos.indices.contains(index) ? photos[index] : nil }

    public var body: some View {
        ZStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(photos) { photo in
                        PhotoPage(photo: photo, loader: loader) { zoomed = $0 }
                            .containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
                #if canImport(UIKit)
                .background(pullDownRecognizer)
                #endif
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentId)
            .scrollIndicators(.hidden)
            .scrollDisabled(zoomed)
            .ignoresSafeArea()
            .offset(y: pullDown)

            chrome
                .opacity(pullDown > 0 ? 0 : 1)
        }
        .background(Color.black.opacity(1 - min(pullDown / 400, 0.6)).ignoresSafeArea())
        .presentationBackground(.black)
        .presentationDragIndicator(.hidden)
        // A downward pan while zoomed in is the image moving, not the
        // sheet going away.
        .interactiveDismissDisabled(zoomed)
    }

    #if canImport(UIKit)
    private var pullDownRecognizer: some View {
        PullDownRecognizer(
            isEnabled: { !zoomed },
            onChange: { pullDown = $0 },
            onEnd: { translation, velocity in
                if translation > 120 || velocity > 800 {
                    onDismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { pullDown = 0 }
                }
            })
    }
    #endif

    private func move(by delta: Int) {
        let target = index + delta
        guard photos.indices.contains(target) else { return }
        withAnimation { currentId = photos[target].id }
    }

    private var chrome: some View {
        VStack {
            HStack(alignment: .top) {
                Spacer()
                if let current {
                    Text(caption(for: current))
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
                        move(by: -1)
                    }
                }
                Spacer()
                if photos.count > 1 {
                    chevron("chevron.right", enabled: index < photos.count - 1, label: "Next photo")
                    {
                        move(by: 1)
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

    private func caption(for photo: Photo) -> String {
        let date = photo.timestamp.display
        return photos.count > 1 ? "\(index + 1) / \(photos.count) · \(date)" : date
    }

    private func chevron(
        _ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
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
    let onZoomChange: (Bool) -> Void

    @State private var state: LoadState = .loading
    @State private var attempt = 0
    // The thumbnail this page was opened from, already in the image
    // cache: it stands in for the display image while that loads, so
    // the page opens with the picture in it rather than a spinner on
    // black.
    @State private var preview: PlatformImage?

    private enum LoadState {
        case loading
        case loaded(PlatformImage)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ZStack {
                    if let preview {
                        swiftUIImage(preview)
                            .resizable()
                            .scaledToFit()
                            .ignoresSafeArea()
                    }
                    ProgressView()
                        .tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let image):
                PhotoViewer(image: image, onZoomChange: onZoomChange)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(photo.accessibilityDescription)
                    .accessibilityHint("Pinch to zoom. Swipe for the next photo.")
                    .accessibilityAddTraits(.isImage)
            case .failed(let message):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text("Couldn't load photo")
                        .font(.headline)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Retry") { attempt += 1 }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: "\(photo.id):\(attempt)") {
            state = .loading
            async let thumbnail = try? loader.loadImage(from: photo.thumbnailURL)
            async let display = loader.loadImage(from: photo.displayImageURL)
            preview = await thumbnail
            do {
                state = .loaded(try await display)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func swiftUIImage(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }
}
