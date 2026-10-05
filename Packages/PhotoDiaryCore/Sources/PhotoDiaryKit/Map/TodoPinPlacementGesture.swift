#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftUI

/// LongPressGesture has no location and a sequenced drag reports only
/// once the finger moves, so a zero-distance drag alongside catches the
/// touch-down point. It also reports each lift at once, unlike MapKit's
/// tap, which waits out a possible double tap.
@MainActor
struct MapTouchGestures {
    let proxy: MapProxy
    let isMovingPin: () -> Bool
    let pressPoint: Binding<CGPoint?>
    let placing: Binding<CLLocationCoordinate2D?>
    let onPlaced: (CLLocationCoordinate2D) -> Void
    let onTap: () -> Void

    var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { pressPoint.wrappedValue = $0.startLocation }
            .onEnded { value in
                if hypot(value.translation.width, value.translation.height) < 10 { onTap() }
            }
            .simultaneously(
                with: LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onChanged { value in
                        guard !isMovingPin(), case .second(true, let drag) = value,
                            let point = drag?.location ?? pressPoint.wrappedValue
                        else { return }
                        placing.wrappedValue = proxy.convert(point, from: .local)
                    }
                    .onEnded { _ in
                        if let coordinate = placing.wrappedValue { onPlaced(coordinate) }
                    }
            )
    }
}
#endif
