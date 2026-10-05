import Observation
import SwiftUI

public enum AppTab: String, Codable, Hashable, Sendable {
    case map
    case calendar
}

/// A cross-tab "show this photo" request, consumed by the target surface.
/// Its own store rather than a binding threaded through every surface.
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

    public func settledOnMap() {
        pendingOnMap = nil
    }

    public func settledInCalendar() {
        pendingInCalendar = nil
    }
}
