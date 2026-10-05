#if canImport(MapKit) && canImport(UIKit)
import MapKit
import SwiftData
import SwiftUI

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

struct DraggedPin: Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: DraggedPin, rhs: DraggedPin) -> Bool {
        lhs.id == rhs.id
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

/// MapContent can't hold state, so live positions come in from
/// MapPhotoView. A pin's long-press-then-drag is high priority, so a press
/// that starts on a pin moves it instead of dropping a new one under it.
struct TodoPinsMapContent: MapContent {
    let pins: [TodoPin]
    let draggedPin: DraggedPin?
    let provisionalPin: CLLocationCoordinate2D?
    let proxy: MapProxy
    let onMoveChanged: (TodoPin, CLLocationCoordinate2D) -> Void
    let onMoveEnded: (TodoPin) -> Void
    let onTap: (MapPinSelection) -> Void
    /// Moving without a drag, for VoiceOver.
    let onMoveToCenter: (TodoPin) -> Void

    var body: some MapContent {
        ForEach(pins) { pin in
            let lifted = draggedPin?.id == pin.id
            let coordinate = lifted ? draggedPin!.coordinate : pin.coordinate
            let selection = MapPinSelection.todo(pin.id)
            Annotation("", coordinate: coordinate) {
                MapAnnotations.todoMarker(lifted: lifted, note: pin.note)
                    .highPriorityGesture(moveGesture(for: pin))
                    // Simultaneous, not plain: the high-priority long press
                    // claims the touch and starves an ordinary tap gesture.
                    .simultaneousGesture(TapGesture().onEnded { onTap(selection) })
                    .accessibilityAction(named: Text("Move to map center")) {
                        onMoveToCenter(pin)
                    }
            }
            .tag(selection)
        }
        if let provisionalPin {
            Annotation("", coordinate: provisionalPin) {
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
