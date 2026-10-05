import SwiftUI

extension Photo {
    var accessibilityDescription: String {
        let date = timestamp.display
        return title.isEmpty
            ? String(localized: "Photo, \(date)")
            : String(localized: "\(title), \(date)")
    }
}
