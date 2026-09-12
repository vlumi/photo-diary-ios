#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftUI

/// Long-press on the map shows a provisional pin under the finger
/// that follows it until release, then opens the editor for its note;
/// the pin stays provisional until saved there. LongPressGesture has
/// no location and the sequenced drag only reports once the finger
/// moves, so a zero-distance drag alongside catches the touch-down
/// point for a press that stays put (a simulator click never moves).
/// Simultaneous with the map's own gestures: a moving finger fails
/// the long-press, so panning is untouched. A press on a pin sets
/// `moving` first (its gesture has priority and a shorter delay), so
/// it never drops a second pin underneath.
///
/// The zero-distance drag also reports every touch the moment it
/// lifts, which MapKit's own tap does not: it waits out a possible
/// double tap first. A touch that barely moved is reported as a tap.
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
