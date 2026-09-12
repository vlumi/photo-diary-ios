#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

/// What the todo-pin editor sheet is opened for.
enum MapEditorPresentation: Identifiable {
    case create(CLLocationCoordinate2D)
    case edit(TodoPin)

    var id: String {
        switch self {
        case .create(let c): return "create:\(c.latitude),\(c.longitude)"
        case .edit(let pin): return "edit:\(pin.id)"
        }
    }

    var mode: TodoPinEditor.Mode {
        switch self {
        case .create(let c): return .create(latitude: c.latitude, longitude: c.longitude)
        case .edit(let pin): return .edit(pin)
        }
    }
}

/// Where a pin is being dragged to, live, before it's saved.
struct MovingPin: Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: MovingPin, rhs: MovingPin) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// The todo-pin layer: every saved pin (the one being dragged follows
/// the finger), plus the provisional pin while the user long-presses to
/// place a new one. MapContent can't hold state, so the live positions
/// come in from MapPhotoView and gesture results go back out as
/// coordinates — converted here through the MapProxy, since the drag
/// reports screen points.
///
/// Long-press-then-drag on a pin is a high-priority gesture so a press
/// that starts on a pin moves it instead of dropping a new one under it;
/// the pin lifts (reports itself as moving) as soon as the press
/// completes, before the map's own long-press could fire.
struct TodoPinsMapContent: MapContent {
    let pins: [TodoPin]
    let moving: MovingPin?
    let placing: CLLocationCoordinate2D?
    let proxy: MapProxy
    let onMoveChanged: (TodoPin, CLLocationCoordinate2D) -> Void
    let onMoveEnded: (TodoPin) -> Void
    let onTap: (String) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            let lifted = moving?.id == pin.id
            let coordinate = lifted ? moving!.coordinate : pin.coordinate
            let tag = "todo:\(pin.id.uuidString)"
            Annotation("", coordinate: coordinate) {
                MapAnnotations.todoMarker(lifted: lifted, note: pin.note)
                    .highPriorityGesture(moveGesture(for: pin))
                    .onTapGesture { onTap(tag) }
            }
            .tag(tag)
        }
        if let placing {
            Annotation("", coordinate: placing) {
                MapAnnotations.todoMarker(lifted: true, note: "")
            }
            .annotationTitles(.hidden)
        }
    }

    private func moveGesture(for pin: TodoPin) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                let coordinate = drag.flatMap { proxy.convert($0.location, from: .global) }
                onMoveChanged(pin, coordinate ?? pin.coordinate)
            }
            .onEnded { _ in onMoveEnded(pin) }
    }
}

extension TodoPin {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
#endif
