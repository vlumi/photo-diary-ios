import Foundation
import PhotoDiaryCore

extension PhotoTimestamp {
    /// Short date and time for captions, in the photo's own local time.
    public var display: String {
        asLocalDate?.formatted(date: .abbreviated, time: .shortened)
            ?? String(format: "%04d-%02d-%02d %02d:%02d", year, month, day, hour, minute)
    }
}
