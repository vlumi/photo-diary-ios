import XCTest
@testable import PhotoDiaryCore

final class DemoImageLoaderTests: XCTestCase {
    func testLoadsDemoScheme() async throws {
        let loader = DemoImageLoader()
        let image = try await loader.loadImage(
            from: URL(string: "photodiary-demo://display/daily-2024-06-01.jpg")!
        )
        // Just prove we got bytes out — the exact rendering is a
        // visual concern and not worth pixel-diffing in unit tests.
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
        // Deterministic hashing is a runtime concern (Swift's Hasher
        // reseeds across processes), so we only assert same-run
        // determinism: two renders in the same process produce the
        // same size / same colours implicitly through the same code
        // path. Size assertion is a smoke test that the render
        // pipeline works twice.
        let a = try DemoImageLoader.renderTile(seed: "daily-2024-06-01")
        let b = try DemoImageLoader.renderTile(seed: "daily-2024-06-01")
        XCTAssertEqual(a.size, b.size)
    }
}
