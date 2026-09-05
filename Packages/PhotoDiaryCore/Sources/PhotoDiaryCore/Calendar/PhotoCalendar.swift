import Foundation

/// Pure helpers that slice a photo list by the calendar dimensions the
/// UI navigates through (year, month, day). Ordering is ascending by
/// EXIF timestamp — matches the site.
public enum PhotoCalendar {
    /// Distinct years that have at least one photo, ascending.
    public static func years(in photos: [Photo]) -> [Int] {
        Array(Set(photos.map { $0.timestamp.year })).sorted()
    }

    /// Distinct months (1-12) with at least one photo in the given
    /// year, ascending.
    public static func months(in year: Int, of photos: [Photo]) -> [Int] {
        let inYear = photos.filter { $0.timestamp.year == year }
        return Array(Set(inYear.map { $0.timestamp.month })).sorted()
    }

    /// Photos taken in the given year, timestamp-ascending.
    public static func photos(in year: Int, of photos: [Photo]) -> [Photo] {
        photos
            .filter { $0.timestamp.year == year }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Photos taken in the given year+month, timestamp-ascending.
    public static func photos(in year: Int, month: Int, of photos: [Photo]) -> [Photo] {
        photos
            .filter { $0.timestamp.year == year && $0.timestamp.month == month }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Groups photos by day-of-month. Order of returned sections is
    /// day-ascending; within each section, photos are
    /// timestamp-ascending. Caller has already filtered to a single
    /// year+month.
    public static func groupByDay(_ photos: [Photo]) -> [DaySection] {
        let sorted = photos.sorted { $0.timestamp < $1.timestamp }
        var byDay: [Int: [Photo]] = [:]
        for photo in sorted {
            byDay[photo.timestamp.day, default: []].append(photo)
        }
        return byDay.keys.sorted().map { day in
            DaySection(day: day, photos: byDay[day] ?? [])
        }
    }

    public struct DaySection: Identifiable, Hashable, Sendable {
        public let day: Int
        public let photos: [Photo]

        public var id: Int { day }
    }
}
