#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// A tap recognized on an annotation view, ahead of MapKit.
struct OwnTap {
    let tag: String
    let at: Date
    var handled: Bool
}

private enum MapLoadState {
    case loading
    case loaded([PhotoMapPin])
    case empty
    case failed(LoadFailure)
}

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
public struct MapPhotoView: View {
    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.imageLoader) private var loaderBox
    @Environment(MapFocusStore.self) private var focus
    @Environment(\.modelContext) var modelContext
    @Environment(\.restoration) private var restoration

    @State private var state: MapLoadState = .loading
    @State private var attempt = 0
    // A reload while pins are already on screen keeps the map mounted
    // (tearing it down re-applies the camera and visibly re-fits) and
    // shows a thin bar instead.
    @State private var isRefreshing = false
    @State private var notice: MapNotice?
    // MapKit's selection drives every tap: no Button per annotation, so
    // a pinch that lands on a pin isn't claimed as a tap first.
    @State var selection: String?
    @State var cameraPosition: MapCameraPosition = .automatic
    @State private var presented: PhotoPagerSelection?
    // The tag whose callout is showing (a single photo or a pile); nil
    // when nothing is selected or the selection zoomed instead.
    @State var calloutFor: String?
    // Keep the loaded photos around so tap-to-viewer can resolve a
    // pin's photoId back to a full Photo without a re-fetch.
    @State private var photosById: [String: Photo] = [:]
    @State var locator = UserLocationController()
    @State var follow = FollowState()
    // The tag a pin's own tap gesture selected, when, and whether the
    // selection change for it has been handled. MapKit reports the
    // same tap as a selection about half a second later, after its
    // double-tap wait; within that window the map's tap-to-deselect
    // stands down, and a cluster's second arrival (its echo, after it
    // already zoomed) is dropped.
    @State var ownTap: OwnTap?
    // The tag the map's own tap-to-deselect cleared, and when: MapKit
    // reports that same tap half a second later as a selection of it
    // again, which is dropped unless a newer own tap chose it.
    @State var ownDeselect: OwnTap?
    @Environment(\.scenePhase) private var scenePhase
    @State var editorPresentation: MapEditorPresentation?
    @State var currentRegion: MKCoordinateRegion?
    @State private var showingList = false
    @State var clusters: [MapCluster] = []
    // Todo-pin gestures: the pin being dragged (live position) and the
    // provisional pin while long-pressing to place a new one.
    @State var moving: MovingPin?
    @State var placing: CLLocationCoordinate2D?
    @State var pressPoint: CGPoint?
    @Query(sort: TodoPinStore.sortOrder) private var todoPins: [TodoPin]

    /// Initial zoom around the latest photo: roughly a country to a
    /// small continent, so the neighborhood is legible but the wider
    /// spread is visible too.
    static let initialSpanDegrees = 20.0
    /// Locate / show-on-map framing: close enough to read the street,
    /// wide enough to keep the surroundings.
    static let closeUpMeters: CLLocationDistance = 300

    public init() {}

    public var body: some View {
        content
            .task(id: "\(scopeKey):\(attempt)") { await load() }
            .fullScreenCover(item: $presented) { selection in
                PhotoPagerSheet(
                    selection: selection,
                    loader: loaderBox.loader,
                    onDismiss: { presented = nil }
                )
            }
            .sheet(item: $editorPresentation) { presentation in
                TodoPinEditor(mode: presentation.mode) {
                    editorPresentation = nil
                    placing = nil
                }
            }
            .sheet(isPresented: $showingList) {
                TodoPinListSheet(
                    mapCenter: currentRegion?.center,
                    onDismiss: { showingList = false },
                    onSelect: { pin in
                        showingList = false
                        frame(pin.coordinate, meters: Self.closeUpMeters)
                    }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let failure):
            LoadFailureView(title: "Couldn't load map", failure: failure) { attempt += 1 }
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
        // A lifted pin owns the finger: no map pan/zoom underneath it.
        Map(
            position: $cameraPosition,
            interactionModes: moving == nil && placing == nil ? .all : [],
            selection: $selection
        ) {
            layers(proxy: proxy)
        }
        .simultaneousGesture(placementGesture(proxy))
        .onMapCameraChange(frequency: .onEnd) { context in
            cameraSettled(context.region, pins: pins)
        }
        .overlay(alignment: .bottomTrailing) { controls }
        .overlay(alignment: .topLeading) { frontPageButton }
        .overlay(alignment: .top) {
            MapTopBanners(
                isRefreshing: isRefreshing, locationError: locator.lastError,
                notice: notice, onDismissNotice: { notice = nil }
            )
        }
        .onAppear { locator.startTracking() }
        .onDisappear { locator.stopTracking() }
        .onChange(of: locator.freshFix) {
            // The fix a tap (or a return to the foreground) asked for.
            guard follow.isOn, let here = locator.lastLocation else { return }
            keepUp(with: here)
        }
        .onChange(of: locator.updateCount) {
            guard follow.isDue(), let here = locator.lastLocation else { return }
            keepUp(with: here)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active, follow.isOn { locator.locate() }
        }
        .onChange(of: selection) { _, selected in selectionChanged(selected, pins: pins) }
        .onChange(of: focus.pending?.id) {
            applyPendingFocus()
        }
    }

    private func layers(proxy: MapProxy) -> some MapContent {
        MapLayers(
            clusters: clusters, todoPins: todoPins, moving: moving, placing: placing,
            userLocation: locator.lastLocation, callout: calloutContent, proxy: proxy,
            onMoveChanged: { pin, coordinate in
                moving = MovingPin(id: pin.id, coordinate: coordinate)
            },
            onMoveEnded: finishMove,
            onTapPin: { tag in
                ownTap = OwnTap(tag: tag, at: Date(), handled: false)
                selection = tag
            },
            calloutView: calloutView
        )
    }

    // Tags are "kind:id" so one selection binding covers every layer.
    // Returns whether the selection should stay (a callout is showing).
    @ViewBuilder
    private func calloutView(_ callout: MapCalloutContent) -> some View {
        calloutContentView(callout)
            .simultaneousGesture(
                TapGesture().onEnded {
                    ownTap = OwnTap(tag: callout.tag, at: Date(), handled: true)
                })
    }

    @ViewBuilder
    private func calloutContentView(_ callout: MapCalloutContent) -> some View {
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
        MapCalloutContent.resolve(
            tag: calloutFor, clusters: clusters, photosById: photosById,
            todoPins: todoPins, moving: moving)
    }

    /// The camera came to rest: remember where (for a relaunch), redo
    /// the pins under it, and treat a user move as the end of a locate.
    private func cameraSettled(_ region: MKCoordinateRegion, pins: [PhotoMapPin]) {
        currentRegion = region
        if let scope = registry.scope {
            restoration.save(MapCamera(region), forKey: "camera." + scope.key)
        }
        recluster(pins: pins, region: region)
        if cameraPosition.positionedByUser { follow.stop() }
    }

    private func recluster(pins: [PhotoMapPin], region: MKCoordinateRegion) {
        clusters = MapClustering.clusters(pins: pins, in: MapRegion(region))
    }

    private var scopeKey: String {
        guard let scope = registry.scope else { return "" }
        return "\(scope.instanceId)/\(scope.galleryId ?? "*")"
    }

    private var controls: some View {
        MapControlsOverlay(
            todoCount: todoPins.count,
            isFollowing: follow.isOn,
            onListPins: { showingList = true },
            onLocate: toggleFollow
        )
    }

    private func load() async {
        let hadPins: Bool
        if case .loaded = state { hadPins = true } else { hadPins = false }
        if hadPins { isRefreshing = true } else { state = .loading }
        defer { isRefreshing = false }
        notice = nil
        // A saved camera stands in for "where the user was", so the
        // first load reclusters under it instead of framing the latest
        // photo.
        if currentRegion == nil, let scope = registry.scope,
            let saved = restoration.load(MapCamera.self, forKey: "camera." + scope.key)
        {
            currentRegion = saved.region
            cameraPosition = .region(saved.region)
        }
        guard let instance = registry.activeInstance else {
            state = .failed(LoadFailure(message: "No active instance."))
            return
        }
        // What the cache holds goes up first; the network then refreshes
        // it behind the bar, exactly like a scope revisit.
        var havePins = hadPins
        if !havePins, let cached = try? await gather(from: instance, cached: true) {
            place(cached)
            havePins = true
            isRefreshing = true
        }
        do {
            place(try await gather(from: instance, cached: false) ?? [])
        } catch {
            if registry.evictIfAccessLost(error) { return }
            // A failed refresh keeps the pins already on screen and says so.
            if havePins {
                notice = .refreshFailed(error.localizedDescription)
            } else {
                state = .failed(LoadFailure(error))
            }
        }
    }

    private func gather(from instance: any Instance, cached: Bool) async throws -> [Photo]? {
        guard let scope = registry.scope else { return nil }
        return try await MapPhotoGathering.photos(of: scope, from: instance, cached: cached)
    }

    private func place(_ photos: [Photo]) {
        photosById = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        show(pins: PhotoMapping.pins(from: photos), of: photos)
    }

    /// Pins on screen: recluster under the standing camera on a
    /// refresh, or open around the latest photo on a first load.
    private func show(pins: [PhotoMapPin], of photos: [Photo]) {
        if pins.isEmpty {
            state = .empty
            clusters = []
            notice = .noLocatedPhotos
        } else {
            notice = nil
            state = .loaded(pins)
            if let region = currentRegion {
                // A refresh: the user's camera stands; only the pins
                // under it are recomputed.
                recluster(pins: pins, region: region)
            } else if let latest = PhotoMapping.latestGeotagged(in: photos),
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

    func frame(_ coord: CLLocationCoordinate2D, meters: CLLocationDistance) {
        let region = MKCoordinateRegion(
            center: coord, latitudinalMeters: meters, longitudinalMeters: meters)
        cameraPosition = .region(region)
        currentRegion = region
    }
}
// MARK: - Front page

extension MapPhotoView {
    fileprivate var frontPageButton: some View {
        MapRoundButton("square.grid.2x2", tint: .secondary) { registry.leaveScope() }
            .accessibilityLabel("Photo Diary")
            .padding(.leading, 16)
            .padding(.top, 8)
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
