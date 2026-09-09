import SwiftUI

extension Photo {
    /// What VoiceOver reads for this photo anywhere it appears: the
    /// title when there is one, and the date either way.
    var accessibilityDescription: String {
        let date = timestamp.display
        return title.isEmpty
            ? String(localized: "Photo, \(date)")
            : String(localized: "\(title), \(date)")
    }
}
