import Foundation

/// The locate button as a mode. While on, the map keeps up with the
/// user's position — at most once per `interval`, so a walk doesn't
/// turn into a jitter — until the user moves the map, which turns it
/// off. The first fix after switching on re-centers at once.
public struct FollowState: Sendable {
    public static let interval: TimeInterval = 10

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

    /// Whether a routine position update should move the camera now.
    public func isDue(at now: Date = Date()) -> Bool {
        guard isOn else { return false }
        guard let lastRecenter else { return true }
        return now.timeIntervalSince(lastRecenter) >= Self.interval
    }

    public mutating func recentered(at now: Date = Date()) {
        lastRecenter = now
    }
}
