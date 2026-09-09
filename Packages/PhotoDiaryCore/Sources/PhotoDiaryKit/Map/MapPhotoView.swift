#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// Map of every geotagged photo across the active instance's
/// galleries. Tapping a pin shows a callout; tapping that opens the
/// paging viewer.
///
/// Pins are culled to the viewport and grid-clustered on every camera
/// settle (MapClustering), so thousands of photos render as a few
/// dozen annotations. A cluster zooms into its bounding box on tap;
/// a pile at one exact spot shows a callout to browse its photos.
///
/// Load fans out to every gallery on the active instance so a photo
/// pinned in gallery A shows up next to a pin in gallery B — matches
/// the site's per-instance map. Photos without coordinates are
/// silently omitted; if the whole result is empty, the surface shows
/// an unavailable state.
private enum MapEditorPresentation: Identifiable {
    case edit(TodoPin)

    var id: String {
        switch self {
        case .edit(let pin): return "edit:\(pin.id)"
        }
    }
}

private enum MapLoadState {
    case loading
    case loaded([PhotoMapPin])
    case empty
    case failed(String)
}

/// A selected pin's callout: photos (one, or a pile) or a todo note.
private struct MapCalloutContent {
    enum Kind {
        case photos([Photo])
        case todo(TodoPin)
    }
    let tag: String
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
}

public struct MapPhotoView: View {
    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.imageLoader) private var loaderBox
    @Environment(MapFocusStore.self) private var focus
    @Environment(\.modelContext) private var modelContext

    @State private var state: MapLoadState = .loading
    // A reload while pins are already on screen keeps the map mounted
    // (tearing it down re-applies the camera and visibly re-fits) and
    // shows a thin bar instead.
    @State private var isRefreshing = false
    // MapKit's selection drives every tap: no Button per annotation, so
    // a pinch that lands on a pin isn't claimed as a tap first.
    @State private var selection: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var presented: PhotoPagerSelection?
    // The tag whose callout is showing (a single photo or a pile); nil
    // when nothing is selected or the selection zoomed instead.
    @State private var calloutFor: String?
    // Keep the loaded photos around so tap-to-viewer can resolve a
    // pin's photoId back to a full Photo without a re-fetch.
    @State private var photosById: [String: Photo] = [:]
    @State private var locator = UserLocationController()
    @State private var editorPresentation: MapEditorPresentation?
    @State private var currentRegion: MKCoordinateRegion?
    @State private var showingList = false
    @State private var clusters: [MapCluster] = []
    // Todo-pin gestures: the pin being dragged (live position) and the
    // provisional pin while long-pressing to place a new one.
    @State private var moving: MovingPin?
    @State private var placing: CLLocationCoordinate2D?
    @Query(sort: \TodoPin.createdAt, order: .reverse) private var todoPins: [TodoPin]

    /// Initial zoom around the latest photo: roughly a country to a
    /// small continent, so the neighbourhood is legible but the wider
    /// spread is visible too.
    static let initialSpanDegrees = 20.0
    /// Locate / show-on-map framing: close enough to read the street,
    /// wide enough to keep the surroundings.
    static let closeUpMeters: CLLocationDistance = 300

    public init() {}

    public var body: some View {
        content
            .task(id: registry.activeInstanceId) { await load() }
            .fullScreenCover(item: $presented) { selection in
                PhotoPagerSheet(
                    selection: selection,
                    loader: loaderBox.loader,
                    onDismiss: { presented = nil }
                )
            }
            .sheet(item: $editorPresentation) { presentation in
                switch presentation {
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
                        frame(
                            CLLocationCoordinate2D(
                                latitude: pin.latitude, longitude: pin.longitude),
                            meters: Self.closeUpMeters
                        )
                        editorPresentation = .edit(pin)
                    }
                )
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
        MapReader { proxy in
            mapBody(pins: pins, proxy: proxy)
        }
    }

    private func mapBody(pins: [PhotoMapPin], proxy: MapProxy) -> some View {
        Map(position: $cameraPosition, selection: $selection) {
            layers(proxy: proxy)
        }
        .simultaneousGesture(placementGesture(proxy))
        .onMapCameraChange(frequency: .onEnd) { context in
            currentRegion = context.region
            recluster(pins: pins, region: context.region)
        }
        .overlay(alignment: .bottomTrailing) { controls }
        .overlay(alignment: .top) {
            MapTopBanners(isRefreshing: isRefreshing, locationError: locator.lastError)
        }
        .onAppear { locator.startTracking() }
        .onDisappear { locator.stopTracking() }
        .onChange(of: locator.lastLocation?.latitude) {
            if let coord = locator.consumeCenterRequest() {
                frame(coord, meters: Self.closeUpMeters)
            }
        }
        .onChange(of: selection) { _, selected in
            guard let selected else {
                calloutFor = nil
                return
            }
            if !handleSelection(selected, pins: pins) { selection = nil }
        }
        .onChange(of: focus.pending?.id) {
            applyPendingFocus()
        }
    }

    @MapContentBuilder
    private func layers(proxy: MapProxy) -> some MapContent {
        ForEach(clusters) { cluster in
            if cluster.isSingle {
                MapAnnotations.photo(
                    PhotoMapPin(photoId: cluster.photoIds[0], coordinate: cluster.coordinate)
                )
            } else {
                MapAnnotations.cluster(cluster)
            }
        }
        TodoPinsMapContent(
            pins: todoPins, moving: moving, placing: placing, proxy: proxy,
            onMoveChanged: { pin, coordinate in
                moving = MovingPin(id: pin.id, coordinate: coordinate)
            },
            onMoveEnded: finishMove
        )
        if let here = locator.lastLocation {
            MapAnnotations.userMarker(at: here)
        }
        if let callout = calloutContent {
            // Its own annotation, declared last, so it floats above
            // the pin it belongs to. Tagged so a tap inside it reads
            // as "keep this selection" rather than a deselect.
            Annotation("", coordinate: callout.coordinate, anchor: .bottom) {
                calloutView(callout).padding(.bottom, 24)
            }
            .annotationTitles(.hidden)
            .tag("callout:\(callout.tag)")
        }
    }

    // Tags are "kind:id" so one selection binding covers every layer.
    // Returns whether the selection should stay (a callout is showing).
    private func handleSelection(_ tag: String, pins: [PhotoMapPin]) -> Bool {
        let parts = tag.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        switch parts[0] {
        case "photo":
            calloutFor = tag
            return true
        case "cluster":
            guard let cluster = clusters.first(where: { $0.id == parts[1] }) else { return false }
            switch MapClustering.tapAction(for: cluster, pins: pins) {
            case .zoom(let region):
                calloutFor = nil
                cameraPosition = .region(MKCoordinateRegion(region))
                return false
            case .list:
                calloutFor = tag
                return true
            }
        case "callout":
            // A tap inside the callout (its thumbnail or chevrons) also
            // selects the callout annotation; keep the underlying pin
            // selected so the callout stays put.
            selection = parts[1]
            return true
        case "todo":
            calloutFor = tag
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private func calloutView(_ callout: MapCalloutContent) -> some View {
        switch callout.kind {
        case .photos(let photos):
            MapPhotoCallout(photos: photos, loader: loaderBox.loader) { index in
                presented = PhotoPagerSelection(photos: photos, index: index)
            }
        case .todo(let pin):
            TodoPinCallout(note: pin.note) { editorPresentation = .edit(pin) }
        }
    }

    /// The selected photo or pile, resolved against the current
    /// clusters; nil once reclustering has moved it out of view.
    private var calloutContent: MapCalloutContent? {
        guard let tag = calloutFor else { return nil }
        let parts = tag.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "photo":
            guard let photo = photosById[parts[1]],
                let cluster = clusters.first(where: { $0.isSingle && $0.photoIds[0] == parts[1] })
            else { return nil }
            return MapCalloutContent(
                tag: tag, coordinate: cluster.coordinate, kind: .photos([photo]))
        case "cluster":
            guard let cluster = clusters.first(where: { $0.id == parts[1] }) else { return nil }
            let photos = cluster.photoIds.compactMap { photosById[$0] }
            return MapCalloutContent(
                tag: tag, coordinate: cluster.coordinate, kind: .photos(photos))
        case "todo":
            guard let pin = todoPins.first(where: { $0.id.uuidString == parts[1] }) else {
                return nil
            }
            let coordinate = moving?.id == pin.id ? moving!.coordinate : pin.coordinate
            return MapCalloutContent(tag: tag, coordinate: coordinate, kind: .todo(pin))
        default:
            return nil
        }
    }

    // MARK: - Todo pin gestures

    /// Long-press on the map (not on a pin — those take the gesture with
    /// priority) shows a provisional pin under the finger that follows
    /// it until release, then saves. Simultaneous with the map's own
    /// gestures: a moving finger fails the long-press, so panning is
    /// untouched.
    private func placementGesture(_ proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                guard moving == nil, case .second(true, let drag?) = value,
                    let coordinate = proxy.convert(drag.location, from: .local)
                else { return }
                placing = coordinate
            }
            .onEnded { _ in
                if let coordinate = placing {
                    try? TodoPinStore(context: modelContext).create(
                        latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
                placing = nil
            }
    }

    private func finishMove(_ pin: TodoPin) {
        if let moving, moving.id == pin.id {
            try? TodoPinStore(context: modelContext).move(
                pin, latitude: moving.coordinate.latitude, longitude: moving.coordinate.longitude)
        }
        moving = nil
    }

    private func recluster(pins: [PhotoMapPin], region: MKCoordinateRegion) {
        clusters = MapClustering.clusters(pins: pins, in: MapRegion(region))
    }

    private var controls: some View {
        MapControlsOverlay(
            todoCount: todoPins.count,
            onListPins: { showingList = true },
            onLocate: { locator.locate() }
        )
    }

    private func load() async {
        let hadPins: Bool
        if case .loaded = state { hadPins = true } else { hadPins = false }
        if hadPins { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }
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
                if let region = currentRegion {
                    // A refresh: the user's camera stands; only the pins
                    // under it are recomputed.
                    recluster(pins: pins, region: region)
                } else if let latest = PhotoMapping.latestGeotagged(in: unique),
                    let coord = latest.location.coordinates
                {
                    // Open where the diary most recently was, zoomed well
                    // out. Fitting every pin instead gave a world view of
                    // scattered dots. Explicit rather than .automatic: the
                    // annotation set is derived from the region, so the
                    // region has to be known first.
                    let region = MKCoordinateRegion(
                        MapRegion(
                            centerLatitude: coord.latitude,
                            centerLongitude: coord.longitude,
                            latitudeDelta: Self.initialSpanDegrees,
                            longitudeDelta: Self.initialSpanDegrees
                        )
                    )
                    cameraPosition = .region(region)
                    currentRegion = region
                    recluster(pins: pins, region: region)
                }
                applyPendingFocus()
            }
        } catch {
            // A failed refresh keeps the pins already on screen.
            if !hadPins { state = .failed(error.localizedDescription) }
        }
    }

    /// "Show on map" from the viewer: frame the photo's spot closely.
    /// Called when the request arrives and again once pins have loaded,
    /// whichever comes second.
    private func applyPendingFocus() {
        guard case .loaded = state, let photo = focus.pending,
            let coord = photo.location.coordinates
        else { return }
        _ = focus.consume()
        frame(coord, meters: Self.closeUpMeters)
    }

    private func frame(_ coord: CLLocationCoordinate2D, meters: CLLocationDistance) {
        let region = MKCoordinateRegion(
            center: coord, latitudinalMeters: meters, longitudinalMeters: meters)
        cameraPosition = .region(region)
        currentRegion = region
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
