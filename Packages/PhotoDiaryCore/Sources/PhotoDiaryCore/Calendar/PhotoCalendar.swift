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

    /// Groups photos by calendar day. Order of returned sections is
    /// date-ascending; within each section, photos are
    /// timestamp-ascending. Caller has already filtered to a single
    /// year, or a single year+month.
    public static func groupByDay(_ photos: [Photo]) -> [DaySection] {
        let sorted = photos.sorted { $0.timestamp < $1.timestamp }
        var byDay: [Int: [Photo]] = [:]
        for photo in sorted {
            byDay[DaySection.key(photo.timestamp), default: []].append(photo)
        }
        return byDay.keys.sorted().map { key in
            DaySection(month: key / 100, day: key % 100, photos: byDay[key] ?? [])
        }
    }

    public struct DaySection: Identifiable, Hashable, Sendable {
        public let month: Int
        public let day: Int
        public let photos: [Photo]

        public var id: Int { month * 100 + day }

        static func key(_ timestamp: PhotoTimestamp) -> Int {
            timestamp.month * 100 + timestamp.day
        }
    }
}
