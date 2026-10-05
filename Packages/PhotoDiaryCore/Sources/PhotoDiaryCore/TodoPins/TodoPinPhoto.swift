import CoreGraphics

/// Sizing for the snapshot a todo pin can carry. It's a reminder of
/// what the place looks like, not a photo to keep, so it's stored
/// small: scaled down to just under a megapixel, aspect kept.
public enum TodoPinPhoto {
    public static let maxPixels = 1_000_000
    public static let jpegQuality: CGFloat = 0.7

    /// The pixel size to store an image of `size` pixels at: the size
    /// itself when it's already under the limit, otherwise the largest
    /// whole-pixel size of the same aspect that is.
    public static func storedSize(for size: CGSize) -> CGSize {
        let pixels = size.width * size.height
        guard pixels >= CGFloat(maxPixels) else { return size }
        let scale = (CGFloat(maxPixels - 1) / pixels).squareRoot()
        return CGSize(
            width: max(1, (size.width * scale).rounded(.down)),
            height: max(1, (size.height * scale).rounded(.down)))
    }
}
