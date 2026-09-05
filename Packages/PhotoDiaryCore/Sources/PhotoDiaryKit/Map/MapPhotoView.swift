#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftUI

/// Map of every geotagged photo across the active instance's
/// galleries. Tapping a pin opens PhotoViewerSheet.
///
/// Load fans out to every gallery on the active instance so a photo
/// pinned in gallery A shows up next to a pin in gallery B — matches
/// the site's per-instance map. Photos without coordinates are
/// silently omitted; if the whole result is empty, the surface shows
/// an unavailable state.
public struct MapPhotoView: View {
    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.imageLoader) private var loaderBox

    @State private var state: LoadState = .loading
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var presented: Photo?
    // Keep the loaded photos around so tap-to-viewer can resolve a
    // pin's photoId back to a full Photo without a re-fetch.
    @State private var photosById: [String: Photo] = [:]

    private enum LoadState {
        case loading
        case loaded([PhotoMapPin])
        case empty
        case failed(String)
    }

    public init() {}

    public var body: some View {
        content
            .task(id: registry.activeInstanceId) { await load() }
            .fullScreenCover(item: $presented) { photo in
                PhotoViewerSheet(
                    photo: photo,
                    loader: loaderBox.loader,
                    onDismiss: { presented = nil }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "No map-plottable photos",
                systemImage: "mappin.slash",
                description: Text("No photo on this instance has GPS coordinates.")
            )
        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load map",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded(let pins):
            map(pins: pins)
        }
    }

    private func map(pins: [PhotoMapPin]) -> some View {
        Map(position: $cameraPosition) {
            ForEach(pins) { pin in
                Annotation("", coordinate: pin.coordinate) {
                    Button {
                        if let photo = photosById[pin.photoId] {
                            presented = photo
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open photo")
                }
            }
        }
    }

    private func load() async {
        state = .loading
        guard let instance = registry.activeInstance else {
            state = .failed("No active instance.")
            return
        }
        do {
            let galleries = try await instance.listGalleries()
            var allPhotos: [Photo] = []
            for gallery in galleries {
                let photos = try await instance.listPhotos(inGallery: gallery.id)
                allPhotos.append(contentsOf: photos)
            }
            let pins = PhotoMapping.pins(from: allPhotos)
            photosById = Dictionary(uniqueKeysWithValues: allPhotos.map { ($0.id, $0) })
            if pins.isEmpty {
                state = .empty
            } else {
                state = .loaded(pins)
                cameraPosition = .automatic
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
#else
import SwiftUI

/// MapKit isn't available on all platforms (notably: Linux — Swift-on-server
/// paths for the package). This stub keeps the module importable everywhere
/// while the actual surface only exists on iOS.
public struct MapPhotoView: View {
    public init() {}
    public var body: some View { EmptyView() }
}
#endif
