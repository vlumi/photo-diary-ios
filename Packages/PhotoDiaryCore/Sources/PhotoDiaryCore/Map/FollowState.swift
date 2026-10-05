import Foundation

/// Recenters at most once per `interval`, so a walk doesn't turn into a
/// jitter.
public struct FollowState: Sendable {
    public static let interval: TimeInterval = 10

    /// A view up to this many times wider than the close-up still
    /// shows the neighborhood around the user, so locating keeps it.
    public static let keptZoomFactor = 10.0

    public static func locateMeters(current: Double, closeUp: Double) -> Double {
        current <= closeUp * keptZoomFactor ? current : closeUp
    }

    public private(set) var isOn = false
    private var lastRecenter: Date?

    public init() {}

    public mutating func start() {
        isOn = true
        lastRecenter = nil
    }

    public mutating func stop() {
        isOn = false
        lastRecenter = nil
    }

    public func isDue(at now: Date = Date()) -> Bool {
        guard isOn else { return false }
        guard let lastRecenter else { return true }
        return now.timeIntervalSince(lastRecenter) >= Self.interval
    }

    public mutating func recentered(at now: Date = Date()) {
        lastRecenter = now
    }
}
