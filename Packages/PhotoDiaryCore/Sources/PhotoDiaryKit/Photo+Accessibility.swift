import SwiftUI

extension Photo {
    /// The date, after the photo's place in its set when there's more
    /// than one.
    func caption(at index: Int, of count: Int) -> String {
        let date = timestamp.display
        return count > 1 ? "\(index + 1) / \(count) · \(date)" : date
    }

    var accessibilityDescription: String {
        let date = timestamp.display
        return title.isEmpty
            ? String(localized: "Photo, \(date)")
            : String(localized: "\(title), \(date)")
    }
}
