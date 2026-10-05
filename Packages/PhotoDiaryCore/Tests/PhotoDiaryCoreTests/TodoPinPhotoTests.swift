import CoreGraphics
import Testing

@testable import PhotoDiaryCore

struct TodoPinPhotoTests {
    @Test(arguments: [
        CGSize(width: 4032, height: 3024),
        CGSize(width: 3024, height: 4032),
        CGSize(width: 1000, height: 1000),
        CGSize(width: 8000, height: 10),
    ])
    func largeImagesShrinkUnderAMegapixel(_ size: CGSize) {
        let stored = TodoPinPhoto.storedSize(for: size)
        #expect(stored.width * stored.height < CGFloat(TodoPinPhoto.maxPixels))
        let aspect = size.width / size.height
        #expect(abs(stored.width / stored.height - aspect) < 0.01 * aspect)
    }

    @Test func aCameraFrameKeepsMostOfItsMegapixel() {
        let stored = TodoPinPhoto.storedSize(for: CGSize(width: 4032, height: 3024))
        #expect(stored == CGSize(width: 1154, height: 866))
    }

    @Test func smallImagesStayAsTheyAre() {
        let size = CGSize(width: 640, height: 480)
        #expect(TodoPinPhoto.storedSize(for: size) == size)
    }
}
