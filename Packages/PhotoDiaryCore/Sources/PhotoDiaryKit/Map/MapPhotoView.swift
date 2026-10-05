#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// A tap recognized on an annotation view, ahead of MapKit.
struct OwnTap {
    let selection: MapPinSelection
    let at: Date
    var handled: Bool
}

private enum MapLoadState {
    case loading
    case loaded([PhotoMapPin])
    case empty
    case failed(LoadFailure)
}

/// Every geotagged photo in the scope, culled and clustered to the
/// viewport (MapClustering) on every camera settle. A cluster zooms into
/// its bounds on tap; a pile at one exact spot shows a callout instead.
public struct MapPhotoView: View {
    @Environment(InstanceRegistry.self) private var registry
    @Environment(\.imageLoader) private var imageLoader
    @Environment(PhotoFocusStore.self) private var focus
    @Environment(\.modelContext) var modelContext
    @Environment(\.restoration) private var restoration
    @Environment(\.stageCues) var stageCues

    @State private var state: MapLoadState = .loading
    @State private var attempt = 0
    // A reload while pins are already on screen keeps the map mounted
    // (tearing it down re-applies the camera and visibly re-fits) and
    // shows a thin bar instead.
    @State private var isRefreshing = false
    @State private var notice: MapNotice?
    @State var selection: MapPinSelection?
    @State var cameraPosition: MapCameraPosition = .automatic
    @State private var presented: PhotoPagerSelection?
    // nil also when a selection zoomed in rather than opened a callout.
    @State var calloutSelection: MapPinSelection?
    @State private var photosById: [String: Photo] = [:]
    @State var locator = UserLocationController()
    @State var follow = FollowState()
    // See `selectionEcho`.
    @State var ownTap: OwnTap?
    @State var ownDeselect: OwnTap?
    @Environment(\.scenePhase) private var scenePhase
    @State var editorPresentation: MapEditorPresentation?
    @State private var viewingPhoto: TodoPin?
    @State var currentRegion: MKCoordinateRegion?
    @State var showingList = false
    /// Where the list asked for a new pin; its editor opens once the
    /// list has gone, since two sheets can't be up at once.
    @State var addingAt: CLLocationCoordinate2D?
    @AppStorage("map.pinHintSeen") var pinHintSeen = false
    @State var clusters: [MapCluster] = []
    /// The region `clusters` was built for and how far past it they
    /// reach; pins are rebuilt mid-pan once the camera nears that edge.
    @State var clusteredRegion: MapRegion?
    @State var clusteredMargin = MapClustering.defaultMargin
    @State var draggedPin: DraggedPin?
    @State var provisionalPin: CLLocationCoordinate2D?
    @State var pressPoint: CGPoint?
    @Query(sort: TodoPinStore.sortOrder) var todoPins: [TodoPin]

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
            .task(id: "\(registry.scope?.key ?? ""):\(attempt)") { await load() }
            .sheet(item: $presented) { selection in
                PhotoPagerSheet(
                    selection: selection,
                    loader: imageLoader,
                    onDismiss: { presented = nil },
                    onShowInCalendar: { photo in
                        presented = nil
                        focus.showInCalendar(photo)
                    }
                )
            }
            // However the sheet closes, a swipe included, the pin being
            // placed goes: while it's up, the map can't pan or zoom.
            .sheet(item: $editorPresentation, onDismiss: { provisionalPin = nil }) { presentation in
                TodoPinEditor(mode: presentation.mode) { editorPresentation = nil }
            }
            .fullScreenCover(item: $viewingPhoto) { pin in
                if let photo = pin.photo {
                    TodoPinPhotoViewer(data: photo) { viewingPhoto = nil }
                }
            }
            .sheet(isPresented: $showingList, onDismiss: openPendingAdd) {
                TodoPinListSheet(
                    mapCenter: currentRegion?.center,
                    onDismiss: { showingList = false },
                    onSelect: { pin in
                        showingList = false
                        frame(pin.coordinate, meters: Self.closeUpMeters)
                    },
                    onAddAtCenter: {
                        addingAt = currentRegion?.center
                        showingList = false
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
            // Todo pins can still be dropped anywhere.
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
            interactionModes: draggedPin == nil && provisionalPin == nil ? .all : [],
            selection: $selection
        ) {
            layers(proxy: proxy)
        }
        .simultaneousGesture(touchGestures(proxy))
        .sensoryFeedback(.impact(weight: .medium), trigger: provisionalPin != nil) { _, lifted in
            lifted
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: draggedPin?.id) { before, now in
            before == nil && now != nil
        }
        .onMapCameraChange(frequency: .continuous) { context in
            cameraMoving(context.region, pins: pins)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            cameraSettled(context.region, pins: pins)
        }
        .overlay(alignment: .bottomTrailing) { controls }
        .overlay(alignment: .topLeading) { frontPageButton }
        .overlay(alignment: .top) {
            MapTopBanners(
                isRefreshing: isRefreshing, locationError: locator.lastError,
                locationDenied: locator.isDenied, onDismissLocationError: locator.dismissError,
                notice: notice, onDismissNotice: { notice = nil },
                showsPinHint: showsPinHint, onDismissPinHint: { pinHintSeen = true }
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
        .onChange(of: focus.pendingOnMap?.id) {
            applyPendingFocus()
        }
    }

    private func layers(proxy: MapProxy) -> some MapContent {
        MapLayers(
            clusters: clusters, todoPins: todoPins, draggedPin: draggedPin,
            provisionalPin: provisionalPin,
            userLocation: locator.lastLocation, callout: calloutContent, proxy: proxy,
            onMoveChanged: { pin, coordinate in
                draggedPin = DraggedPin(id: pin.id, coordinate: coordinate)
            },
            onMoveEnded: finishMove,
            onTapPin: { tapped in
                ownTap = OwnTap(selection: tapped, at: Date(), handled: false)
                selection = tapped
            },
            onMovePinToCenter: movePinToCenter,
            photoLabel: { id in
                photosById[id]?.accessibilityDescription ?? String(localized: "Photo")
            },
            calloutView: calloutView
        )
    }

    @ViewBuilder
    private func calloutView(_ callout: MapCalloutContent) -> some View {
        calloutContentView(callout)
            .simultaneousGesture(
                TapGesture().onEnded {
                    ownTap = OwnTap(selection: callout.selection, at: Date(), handled: true)
                })
    }

    @ViewBuilder
    private func calloutContentView(_ callout: MapCalloutContent) -> some View {
        switch callout.kind {
        case .photos(let photos):
            MapPhotoCallout(
                photos: photos, loader: imageLoader,
                onOpen: { index in presented = PhotoPagerSelection(photos: photos, index: index) },
                onClose: { selection = nil }
            )
        case .todo(let pin):
            TodoPinCallout(
                note: pin.note, photo: pin.photo, onOpenPhoto: { viewingPhoto = pin },
                onEdit: { editorPresentation = .edit(pin) },
                onClose: { selection = nil })
        }
    }

    private var calloutContent: MapCalloutContent? {
        MapCalloutContent.resolve(
            calloutSelection, clusters: clusters, photosById: photosById,
            todoPins: todoPins, draggedPin: draggedPin)
    }

    private func cameraSettled(_ region: MKCoordinateRegion, pins: [PhotoMapPin]) {
        currentRegion = region
        if let scope = registry.scope {
            restoration.save(MapRegion(region), .camera, in: scope)
        }
        recluster(pins: pins, region: region)
        if cameraPosition.positionedByUser { follow.stop() }
        takeStagedCues()
    }

    func recluster(pins: [PhotoMapPin], region: MKCoordinateRegion) {
        let region = MapRegion(region)
        let build = MapClustering.build(pins: pins, in: region)
        // Each new set re-renders every annotation; a small pan mostly
        // rebuilds the same one.
        if build.clusters != clusters { clusters = build.clusters }
        clusteredRegion = region
        clusteredMargin = build.margin
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
            let saved = restoration.load(MapRegion.self, .camera, in: scope)
        {
            let region = MKCoordinateRegion(saved)
            currentRegion = region
            cameraPosition = .region(region)
        }
        guard let instance = registry.activeInstance else {
            state = .failed(LoadFailure(message: String(localized: "No active instance.")))
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

    private func show(pins: [PhotoMapPin], of photos: [Photo]) {
        if pins.isEmpty {
            state = .empty
            clusters = []
            notice = .noLocatedPhotos
        } else {
            notice = nil
            state = .loaded(pins)
            if let region = currentRegion {
                recluster(pins: pins, region: region)
            } else if let latest = PhotoMapping.latestGeotagged(in: photos),
                let coord = latest.location.coordinates
            {
                // Fitting every pin gives a world of scattered dots. Explicit,
                // not .automatic: clustering needs the region up front.
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

    /// Called when the request arrives and again once pins have loaded,
    /// whichever comes second.
    private func applyPendingFocus() {
        guard case .loaded = state, let photo = focus.pendingOnMap,
            let coord = photo.location.coordinates
        else { return }
        focus.settledOnMap()
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
            .accessibilityLabel("Switch gallery")
            .padding(.leading, 16)
            .padding(.top, 8)
    }
}

#else
import SwiftUI

/// Lets `swift test` build the package on macOS, which has no UIKit.
public struct MapPhotoView: View {
    public init() {}
    public var body: some View { EmptyView() }
}
#endif
