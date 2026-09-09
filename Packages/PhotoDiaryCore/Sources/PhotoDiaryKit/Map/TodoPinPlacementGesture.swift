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
@MainActor
func todoPinPlacementGesture(
    proxy: MapProxy,
    isMovingPin: @escaping () -> Bool,
    pressPoint: Binding<CGPoint?>,
    placing: Binding<CLLocationCoordinate2D?>,
    onPlaced: @escaping (CLLocationCoordinate2D) -> Void
) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
        .onChanged { pressPoint.wrappedValue = $0.startLocation }
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
#endif
