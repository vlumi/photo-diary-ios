import XCTest
@testable import PhotoDiaryCore

final class DemoImageLoaderTests: XCTestCase {
    func testLoadsDemoScheme() async throws {
        let loader = DemoImageLoader()
        let image = try await loader.loadImage(
            from: URL(string: "photodiary-demo://display/daily-2024-06-01.jpg")!
        )
        #if canImport(UIKit)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        #else
        XCTAssertGreaterThan(image.size.width, 0)
        #endif
    }

    func testRejectsUnknownScheme() async {
        let loader = DemoImageLoader()
        do {
            _ = try await loader.loadImage(from: URL(string: "https://example.com/foo.jpg")!)
            XCTFail("expected throw")
        } catch ImageLoaderError.unsupportedScheme {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testSameSeedRendersConsistentSize() throws {
        // Same run only: Hasher reseeds per process.
        let a = try DemoImageLoader.renderTile(seed: "daily-2024-06-01")
        let b = try DemoImageLoader.renderTile(seed: "daily-2024-06-01")
        XCTAssertEqual(a.size, b.size)
    }
}
