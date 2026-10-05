import Foundation

/// What a tap on the map selected: the value the map's selection binding
/// carries for every layer.
public enum MapPinSelection: Hashable, Sendable {
    case photo(String)
    case cluster(String)
    case todo(UUID)
    /// A tap inside an open callout selects the callout's own annotation.
    indirect case callout(MapPinSelection)

    /// `photo:<id>`, `cluster:<id>` or `todo:<uuid>`, as a staged launch
    /// names a pin.
    public init?(name: String) {
        let parts = name.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[1].isEmpty else { return nil }
        switch parts[0] {
        case "photo": self = .photo(parts[1])
        case "cluster": self = .cluster(parts[1])
        case "todo":
            guard let id = UUID(uuidString: parts[1]) else { return nil }
            self = .todo(id)
        default: return nil
        }
    }

    public var isCluster: Bool {
        if case .cluster = self { return true }
        return false
    }
}
