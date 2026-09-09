#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// The map's annotation views. Plain views, no Buttons: MapKit's
/// selection binding handles taps (tags are "kind:id"), so a pinch that
/// lands on a pin isn't claimed as a tap first. The user marker is drawn
/// last by the caller so it paints above pins and clusters (UserAnnotation
/// sits beneath them), with hit testing off so it never steals a tap.
@MainActor
enum MapAnnotations {
    static func photo(_ pin: PhotoMapPin) -> some MapContent {
        Annotation("", coordinate: pin.coordinate) {
            Image(systemName: "camera.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 2)
                .accessibilityLabel("Open photo")
        }
        .tag("photo:\(pin.photoId)")
    }

    static func cluster(_ cluster: MapCluster) -> some MapContent {
        Annotation("", coordinate: cluster.coordinate) {
            Text("\(cluster.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(minWidth: 32, minHeight: 32)
                .padding(.horizontal, 4)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
                .accessibilityLabel("\(cluster.count) photos")
        }
        .tag("cluster:\(cluster.id)")
    }

    static func todo(_ todoPin: TodoPin) -> some MapContent {
        let coord = CLLocationCoordinate2D(
            latitude: todoPin.latitude, longitude: todoPin.longitude
        )
        return Annotation("", coordinate: coord) {
            Image(systemName: "checklist")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(radius: 2)
                .accessibilityLabel(todoPin.note.isEmpty ? "Todo pin" : "Todo: \(todoPin.note)")
        }
        .tag("todo:\(todoPin.id.uuidString)")
    }

    static func userMarker(at coordinate: CLLocationCoordinate2D) -> some MapContent {
        Annotation("", coordinate: coordinate) {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 2)
                .allowsHitTesting(false)
        }
        .annotationTitles(.hidden)
    }
}
#endif
