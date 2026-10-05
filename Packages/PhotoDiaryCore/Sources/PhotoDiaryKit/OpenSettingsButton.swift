import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Where a permission the app was refused can be given back.
struct OpenSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        #if canImport(UIKit)
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
        #endif
    }
}
