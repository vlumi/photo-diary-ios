import CoreGraphics

/// A reminder of what the place looks like, not a photo to keep, so it's
/// stored under a megapixel.
public enum TodoPinPhoto {
    public static let maxPixels = 1_000_000
    public static let jpegQuality: CGFloat = 0.7

    public static func storedSize(for size: CGSize) -> CGSize {
        let pixels = size.width * size.height
        guard pixels >= CGFloat(maxPixels) else { return size }
        let scale = (CGFloat(maxPixels - 1) / pixels).squareRoot()
        return CGSize(
            width: max(1, (size.width * scale).rounded(.down)),
            height: max(1, (size.height * scale).rounded(.down)))
    }
}
