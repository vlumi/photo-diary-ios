#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// Map of every geotagged photo across the active instance's
/// galleries. Tapping a pin opens PhotoViewerSheet.
///
/// Pins are culled to the viewport and grid-clustered on every camera
/// settle (MapClustering), so thousands of photos render as a few
/// dozen annotations. A cluster zooms into its bounding box on tap;
/// a pile at one exact spot lists its photos instead.
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
    @State private var showingList = false
    @State private var clusters: [MapCluster] = []
    @State private var pile: MapCluster?
    // Chosen inside the pile sheet; presented once that sheet is gone
    // so two presentations don't overlap.
    @State private var pendingFromPile: Photo?
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
            .sheet(isPresented: $showingList) {
                TodoPinListSheet(
                    onDismiss: { showingList = false },
                    onSelect: { pin in
                        showingList = false
                        centerOnTodoPin(pin)
                        editorPresentation = .edit(pin)
                    }
                )
            }
            .sheet(
                item: $pile,
                onDismiss: {
                    if let photo = pendingFromPile {
                        pendingFromPile = nil
                        presented = photo
                    }
                }
            ) { cluster in
                ClusterPhotosSheet(
                    photos: cluster.photoIds.compactMap { photosById[$0] },
                    loader: loaderBox.loader,
                    onSelect: { photo in
                        pendingFromPile = photo
                        pile = nil
                    },
                    onDismiss: { pile = nil }
                )
            }
    }

    private func centerOnTodoPin(_ pin: TodoPin) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
        )
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
            ForEach(clusters) { cluster in
                if cluster.isSingle {
                    photoAnnotation(
                        PhotoMapPin(photoId: cluster.photoIds[0], coordinate: cluster.coordinate)
                    )
                } else {
                    clusterAnnotation(cluster)
                }
            }
            ForEach(todoPins) { todoPin in
                todoAnnotation(todoPin)
            }
            UserAnnotation()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            currentRegion = context.region
            recluster(pins: pins, region: context.region)
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

    private func clusterAnnotation(_ cluster: MapCluster) -> Annotation<Text, some View> {
        Annotation("", coordinate: cluster.coordinate) {
            Button {
                if cluster.isPile {
                    pile = cluster
                } else {
                    zoom(to: cluster)
                }
            } label: {
                Text("\(cluster.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 32, minHeight: 32)
                    .padding(.horizontal, 4)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 2))
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(cluster.count) photos")
        }
    }

    private func zoom(to cluster: MapCluster) {
        cameraPosition = .region(
            MKCoordinateRegion(MapRegion.fitting(cluster.boundingBox, padding: 0.3))
        )
    }

    private func recluster(pins: [PhotoMapPin], region: MKCoordinateRegion) {
        clusters = MapClustering.clusters(pins: pins, in: MapRegion(region))
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
        MapControlsOverlay(
            todoCount: todoPins.count,
            canDropPin: currentRegion != nil,
            onListPins: { showingList = true },
            onDropPin: dropPinAtMapCenter,
            onLocate: { locator.locate() }
        )
    }

    private func dropPinAtMapCenter() {
        guard let region = currentRegion else { return }
        editorPresentation = .create(
            latitude: region.center.latitude,
            longitude: region.center.longitude
        )
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
            // A photo linked into two galleries arrives twice; keep one.
            var seen = Set<String>()
            let unique = allPhotos.filter { seen.insert($0.id).inserted }
            let pins = PhotoMapping.pins(from: unique)
            photosById = Dictionary(uniqueKeysWithValues: unique.map { ($0.id, $0) })
            if pins.isEmpty {
                state = .empty
                clusters = []
            } else {
                state = .loaded(pins)
                if let box = PhotoMapping.boundingBox(of: pins) {
                    // Explicit fit rather than .automatic: the annotation
                    // set is derived from the region, so the region has
                    // to be known first.
                    let region = MKCoordinateRegion(MapRegion.fitting(box))
                    cameraPosition = .region(region)
                    currentRegion = region
                    recluster(pins: pins, region: region)
                }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
extension MKCoordinateRegion {
    fileprivate init(_ region: MapRegion) {
        self.init(
            center: CLLocationCoordinate2D(
                latitude: region.centerLatitude, longitude: region.centerLongitude),
            span: MKCoordinateSpan(
                latitudeDelta: region.latitudeDelta, longitudeDelta: region.longitudeDelta)
        )
    }
}

extension MapRegion {
    fileprivate init(_ region: MKCoordinateRegion) {
        self.init(
            centerLatitude: region.center.latitude,
            centerLongitude: region.center.longitude,
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
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
