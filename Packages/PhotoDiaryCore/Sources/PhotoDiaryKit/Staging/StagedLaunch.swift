import Foundation
import MapKit
import SwiftData
import SwiftUI

/// What a staged launch (LaunchStage) sets up before the first frame:
/// the scope, the restoration store the screens read their tab, camera
/// and calendar path from, and the todo pins on the map. All of it in
/// memory.
extension LaunchStage {
    @MainActor
    func open(in registry: InstanceRegistry) {
        switch opening {
        case .unchanged: break
        case .frontPage: registry.leaveScope()
        case .scope(let scope): registry.enter(scope)
        }
    }

    func restoration(for scope: Scope?) -> any RestorationStore {
        let store = InMemoryRestorationStore()
        guard let scope else { return store }
        if let tab = tab.flatMap(AppTab.init(rawValue:)) {
            store.save(tab, forKey: "tab." + scope.key)
        }
        if let camera {
            store.save(
                MapCamera(
                    MKCoordinateRegion(
                        MapRegion(
                            centerLatitude: camera.latitude, centerLongitude: camera.longitude,
                            latitudeDelta: camera.latitudeDelta,
                            longitudeDelta: camera.longitudeDelta))),
                forKey: "camera." + scope.key)
        }
        if let calendar {
            store.save(
                Self.calendarPath(to: calendar, inGalleryScope: scope.galleryId != nil),
                forKey: "calendar." + scope.key)
        }
        return store
    }

    /// The stack a user would have tapped down to the stop; a gallery
    /// scope's root is already its year list.
    static func calendarPath(to stop: CalendarStop, inGalleryScope: Bool) -> [CalendarRoute] {
        var path: [CalendarRoute] = inGalleryScope ? [] : [.years(galleryId: stop.galleryId)]
        if let year = stop.year {
            path.append(.months(galleryId: stop.galleryId, year: year))
            if let month = stop.month {
                path.append(.grid(galleryId: stop.galleryId, year: year, month: month))
            }
        }
        return path
    }

    @MainActor
    func todoPinContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: TodoPin.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = TodoPinStore(context: container.mainContext)
        // Listed newest first: the first pin given is created last.
        for pin in pins.reversed() {
            try store.create(latitude: pin.latitude, longitude: pin.longitude, note: pin.note)
        }
        return container
    }
}

/// The parts of a stage that happen once a screen is up: the photo the
/// calendar opens, the pin the map selects, the sheet that opens. Each
/// is taken once, so closing it doesn't bring it back.
final class StageCues: @unchecked Sendable {
    private var photoId: String?
    private var selection: String?
    private var sheet: LaunchStage.Sheet?
    /// Staged shots show the app as a regular user sees it, without
    /// first-run hints.
    let isStaged: Bool

    init(_ stage: LaunchStage? = nil) {
        isStaged = stage != nil
        photoId = stage?.photoId
        selection = stage?.selection
        sheet = stage?.sheet
    }

    func takePhoto(among ids: [String]) -> String? {
        guard let photoId, ids.contains(photoId) else { return nil }
        self.photoId = nil
        return photoId
    }

    func takeSelection() -> String? {
        defer { selection = nil }
        return selection
    }

    func takeSheet(_ wanted: LaunchStage.Sheet) -> Bool {
        guard sheet == wanted else { return false }
        sheet = nil
        return true
    }
}

private struct StageCuesKey: EnvironmentKey {
    static let defaultValue = StageCues()
}

extension EnvironmentValues {
    var stageCues: StageCues {
        get { self[StageCuesKey.self] }
        set { self[StageCuesKey.self] = newValue }
    }
}
