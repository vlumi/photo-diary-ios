import Observation
import SwiftUI

/// The app's tabs, so a surface can ask the shell to switch.
public enum AppTab: String, Codable, Hashable, Sendable {
    case map
    case calendar
}

/// A cross-tab request: "show this photo on the map", or "show it in
/// the calendar". The surface that has the photo sets it; the shell
/// switches tabs; the target surface takes the photo and clears the
/// request, framing its spot on the map or scrolling to it among the
/// day's photos in the calendar. Kept as its own small store rather
/// than threading a binding through every surface.
@Observable
@MainActor
public final class PhotoFocusStore {
    public private(set) var pendingOnMap: Photo?
    public private(set) var pendingInCalendar: Photo?

    public init() {}

    public func showOnMap(_ photo: Photo) {
        pendingOnMap = photo
    }

    public func showInCalendar(_ photo: Photo) {
        pendingInCalendar = photo
    }

    public func consumeForMap() -> Photo? {
        defer { pendingOnMap = nil }
        return pendingOnMap
    }

    public func consumeForCalendar() -> Photo? {
        defer { pendingInCalendar = nil }
        return pendingInCalendar
    }
}
