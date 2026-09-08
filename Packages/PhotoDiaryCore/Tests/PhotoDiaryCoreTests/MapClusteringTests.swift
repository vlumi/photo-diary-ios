import CoreLocation
import XCTest

@testable import PhotoDiaryCore

final class MapClusteringTests: XCTestCase {
    private func pin(_ id: String, _ lat: Double, _ lng: Double) -> PhotoMapPin {
        PhotoMapPin(photoId: id, coordinate: .init(latitude: lat, longitude: lng))
    }

    // Tokyo-ish viewport, roughly 0.2° across.
    private let tokyo = MapRegion(
        centerLatitude: 35.68, centerLongitude: 139.76, latitudeDelta: 0.2, longitudeDelta: 0.2)

    func testPinsOutsideTheRegionAndMarginAreCulled() {
        let pins = [pin("in", 35.68, 139.76), pin("far", 60.17, 24.94)]
        let clusters = MapClustering.clusters(pins: pins, in: tokyo)
        XCTAssertEqual(clusters.flatMap(\.photoIds), ["in"])
    }

    func testPinsJustOutsideTheViewportButInsideTheMarginAreKept() {
        // 0.2° span with 25% margin → kept up to 0.15° from centre.
        let pins = [pin("edge", 35.68, 139.76 + 0.14)]
        XCTAssertEqual(MapClustering.clusters(pins: pins, in: tokyo).count, 1)
        let beyond = [pin("beyond", 35.68, 139.76 + 0.16)]
        XCTAssertEqual(MapClustering.clusters(pins: beyond, in: tokyo).count, 0)
    }

    func testNearbyPinsMergeIntoOneClusterWithCentroidAndBox() {
        let pins = [pin("a", 35.6800, 139.7600), pin("b", 35.6802, 139.7604)]
        let clusters = MapClustering.clusters(pins: pins, in: tokyo)
        XCTAssertEqual(clusters.count, 1)
        let c = clusters[0]
        XCTAssertEqual(c.count, 2)
        XCTAssertFalse(c.isSingle)
        XCTAssertEqual(c.latitude, 35.6801, accuracy: 1e-9)
        XCTAssertEqual(c.longitude, 139.7602, accuracy: 1e-9)
        XCTAssertEqual(c.boundingBox.minLng, 139.7600)
        XCTAssertEqual(c.boundingBox.maxLng, 139.7604)
        XCTAssertFalse(c.isPile, "spread-out pins can be zoomed apart")
    }

    func testSameCoordinatePinsFormAPile() {
        let pins = (0..<5).map { pin("p\($0)", 35.68, 139.76) }
        let clusters = MapClustering.clusters(pins: pins, in: tokyo)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertTrue(clusters[0].isPile)
        XCTAssertEqual(clusters[0].count, 5)
    }

    func testAnnotationCountIsBoundedRegardlessOfPinCount() {
        var pins: [PhotoMapPin] = []
        for i in 0..<5000 {
            let lat = 35.58 + Double(i % 100) * 0.002
            let lng = 139.66 + Double(i / 100) * 0.004
            pins.append(pin("p\(i)", lat, lng))
        }
        let clusters = MapClustering.clusters(pins: pins, in: tokyo, columns: 6)
        // 6 columns over the padded span, square cells → a few dozen
        // cells at most; every pin is accounted for exactly once.
        XCTAssertLessThan(clusters.count, 120)
        XCTAssertEqual(clusters.reduce(0) { $0 + $1.count }, 5000)
    }

    func testZoomingInSplitsAClusterIntoSingles() {
        // Same pair the merge test uses: one cluster at city zoom …
        let pins = [pin("a", 35.6800, 139.7600), pin("b", 35.6820, 139.7640)]
        XCTAssertEqual(MapClustering.clusters(pins: pins, in: tokyo).count, 1)
        // … two singles once the viewport is a few hundred metres across.
        let zoomed = MapRegion(
            centerLatitude: 35.681, centerLongitude: 139.762,
            latitudeDelta: 0.006, longitudeDelta: 0.006)
        let near = MapClustering.clusters(pins: pins, in: zoomed)
        XCTAssertEqual(near.count, 2)
        XCTAssertTrue(near.allSatisfy(\.isSingle))
    }

    func testCellsAreAnchoredToAbsoluteCoordinatesSoPanningDoesNotReshuffle() {
        let pins = [pin("a", 35.6800, 139.7600), pin("b", 35.6802, 139.7604)]
        let before = MapClustering.clusters(pins: pins, in: tokyo)
        var panned = tokyo
        panned.centerLongitude += 0.03
        let after = MapClustering.clusters(pins: pins, in: panned)
        XCTAssertEqual(before.map(\.id), after.map(\.id))
    }

    func testFittingRegionCoversTheBoxWithPadding() {
        let box = PhotoMapping.BoundingBox(minLat: 35, maxLat: 36, minLng: 139, maxLng: 141)
        let region = MapRegion.fitting(box, padding: 0.1)
        XCTAssertEqual(region.centerLatitude, 35.5)
        XCTAssertEqual(region.centerLongitude, 140)
        XCTAssertEqual(region.latitudeDelta, 1.2, accuracy: 1e-9)
        XCTAssertEqual(region.longitudeDelta, 2.4, accuracy: 1e-9)
    }

    func testFittingADegenerateBoxYieldsAUsableWindow() {
        let box = PhotoMapping.BoundingBox(minLat: 35, maxLat: 35, minLng: 139, maxLng: 139)
        let region = MapRegion.fitting(box)
        XCTAssertGreaterThan(region.latitudeDelta, 0.005)
        XCTAssertGreaterThan(region.longitudeDelta, 0.005)
    }
}
