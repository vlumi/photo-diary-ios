import Foundation
import Testing

@testable import PhotoDiaryCore

struct MapPinSelectionTests {
    @Test func pinsAreNamedByKindAndId() {
        let id = UUID()
        #expect(MapPinSelection(name: "photo:a.jpg") == .photo("a.jpg"))
        #expect(MapPinSelection(name: "cluster:12/34") == .cluster("12/34"))
        #expect(MapPinSelection(name: "todo:\(id.uuidString)") == .todo(id))
    }

    @Test(arguments: ["photo", "photo:", "todo:not-a-uuid", "callout:photo:a", "pile:1"])
    func otherNamesSelectNothing(_ name: String) {
        #expect(MapPinSelection(name: name) == nil)
    }

    @Test func aStagedLaunchCanAskForTheFirstTodoPin() throws {
        let todo = try #require(
            LaunchStage(arguments: ["-photodiary-stage", "-photodiary-select", "todo"]))
        #expect(todo.selection == .firstTodo)
        let photo = try #require(
            LaunchStage(arguments: ["-photodiary-stage", "-photodiary-select", "photo:a.jpg"]))
        #expect(photo.selection == .pin(.photo("a.jpg")))
    }
}
