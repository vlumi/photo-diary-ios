import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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
