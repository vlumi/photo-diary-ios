import Observation
import SwiftUI

/// The app's tabs, so a surface can ask the shell to switch.
public enum AppTab: Hashable, Sendable {
    case map
    case calendar
}

/// Cross-tab request: "show this photo on the map". Any surface that
/// has a Photo (the viewer, reached from the calendar) sets `pending`;
/// the shell switches to the Map tab and the map frames the photo's
/// spot, then clears it. Kept as its own small store rather than
/// threading a binding through every surface.
@Observable
@MainActor
public final class MapFocusStore {
    public private(set) var pending: Photo?

    public init() {}

    public func show(_ photo: Photo) {
        pending = photo
    }

    public func consume() -> Photo? {
        defer { pending = nil }
        return pending
    }
}
