#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
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
    @State private var locator = UserLocationController()
    @State private var editorPresentation: EditorPresentation?
    @State private var currentRegion: MKCoordinateRegion?
    @Query(sort: \TodoPin.createdAt, order: .reverse) private var todoPins: [TodoPin]

    private enum EditorPresentation: Identifiable {
        case create(latitude: Double, longitude: Double)
        case edit(TodoPin)

        var id: String {
            switch self {
            case .create(let lat, let lng): return "create:\(lat),\(lng)"
            case .edit(let pin): return "edit:\(pin.id)"
            }
        }
    }

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
            .sheet(item: $editorPresentation) { presentation in
                switch presentation {
                case .create(let lat, let lng):
                    TodoPinEditor(
                        mode: .create(latitude: lat, longitude: lng),
                        onDismiss: { editorPresentation = nil }
                    )
                case .edit(let pin):
                    TodoPinEditor(
                        mode: .edit(pin),
                        onDismiss: { editorPresentation = nil }
                    )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load map",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .empty:
            // Instance had zero geotagged photos, but todo pins can
            // still be dropped anywhere so keep the map interactive
            // instead of hiding it behind an empty-state view.
            map(pins: [])
        case .loaded(let pins):
            map(pins: pins)
        }
    }

    private func map(pins: [PhotoMapPin]) -> some View {
        Map(position: $cameraPosition) {
            ForEach(pins) { pin in
                photoAnnotation(pin)
            }
            ForEach(todoPins) { todoPin in
                todoAnnotation(todoPin)
            }
            UserAnnotation()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            currentRegion = context.region
        }
        .overlay(alignment: .bottomTrailing) { controls }
        .overlay(alignment: .top) { locationErrorBanner }
        .onChange(of: locator.lastLocation?.latitude) {
            centerOnUserLocation()
        }
    }

    private func photoAnnotation(_ pin: PhotoMapPin) -> Annotation<Text, some View> {
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

    private func todoAnnotation(_ todoPin: TodoPin) -> Annotation<Text, some View> {
        let coord = CLLocationCoordinate2D(
            latitude: todoPin.latitude, longitude: todoPin.longitude
        )
        return Annotation("", coordinate: coord) {
            Button {
                editorPresentation = .edit(todoPin)
            } label: {
                Image(systemName: "checklist")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todoPin.note.isEmpty ? "Todo pin" : "Todo: \(todoPin.note)")
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            dropPinButton
            locateButton
        }
        .padding(.trailing, 16)
        .padding(.bottom, 24)
    }

    private var dropPinButton: some View {
        Button {
            dropPinAtMapCenter()
        } label: {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
        .buttonStyle(.plain)
        .disabled(currentRegion == nil)
        .accessibilityLabel("Drop pin at map centre")
    }

    private func dropPinAtMapCenter() {
        guard let region = currentRegion else { return }
        editorPresentation = .create(
            latitude: region.center.latitude,
            longitude: region.center.longitude
        )
    }

    private var locateButton: some View {
        Button {
            locator.locate()
        } label: {
            Image(systemName: "location.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Center on my location")
    }

    @ViewBuilder
    private var locationErrorBanner: some View {
        if let error = locator.lastError {
            Text(error)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func centerOnUserLocation() {
        guard let coord = locator.lastLocation else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 2000,
                longitudinalMeters: 2000
            )
        )
        // One-shot: clear so a subsequent tap on the button triggers
        // a fresh location read + re-centre.
        locator.clearLast()
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
