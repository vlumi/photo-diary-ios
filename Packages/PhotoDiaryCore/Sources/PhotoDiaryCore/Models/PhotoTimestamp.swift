import Foundation

/// EXIF wall-clock capture time. No timezone: EXIF `DateTimeOriginal` is
/// tagless per the spec, and the server stores + returns the digits as
/// the photographer saw them. Comparisons + calendar-bucketing use the
/// component fields directly rather than a `Date` that would drag in a
/// timezone. The optional `Date` accessor is a convenience for UI
/// formatting.
public struct PhotoTimestamp: Hashable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let second: Int

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
    }

    /// A `Date` in the current calendar's local timezone, useful for
    /// short-form display (e.g. `RelativeDateTimeFormatter`). The
    /// digits above are the source of truth.
    public var asLocalDate: Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)
    }

    public static func < (lhs: PhotoTimestamp, rhs: PhotoTimestamp) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        if lhs.minute != rhs.minute { return lhs.minute < rhs.minute }
        return lhs.second < rhs.second
    }
}
