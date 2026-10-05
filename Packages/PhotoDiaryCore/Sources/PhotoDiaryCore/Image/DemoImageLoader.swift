import CoreGraphics
import Foundation
#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#else
import AppKit
private typealias PlatformColor = NSColor
#endif

/// The same URL draws the same tile, so the demo behaves as if its
/// photos were real.
public struct DemoImageLoader: ImageLoader {
    public init() {}

    public func loadImage(from url: URL) async throws -> PlatformImage {
        guard url.scheme == "photodiary-demo" else {
            throw ImageLoaderError.unsupportedScheme(url.scheme ?? "(none)")
        }
        let id = url.lastPathComponent
        return try DemoImageLoader.renderTile(seed: id)
    }

    static func renderTile(seed: String, size: CGSize = CGSize(width: 800, height: 800)) throws
        -> PlatformImage
    {
        let (start, end) = gradientColors(for: seed)
        return try render(size: size) { ctx in
            let colors = [start.cgColor, end.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])
            else {
                throw ImageLoaderError.decodingFailed(URL(string: "demo://" + seed)!)
            }
            ctx.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    /// Stable within a run only: Hasher reseeds per process.
    private static func gradientColors(for seed: String) -> (PlatformColor, PlatformColor) {
        var hasher = Hasher()
        hasher.combine(seed)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        let hue1 = Double((hash >> 0) & 0xFF) / 255.0
        let hue2 = Double((hash >> 16) & 0xFF) / 255.0
        return (
            PlatformColor(hue: hue1, saturation: 0.55, brightness: 0.72, alpha: 1),
            PlatformColor(hue: hue2, saturation: 0.55, brightness: 0.35, alpha: 1)
        )
    }
}

#if canImport(UIKit)
private func render(size: CGSize, draw: (CGContext) throws -> Void) throws -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    var captured: Error?
    let image = renderer.image { rendererContext in
        do {
            try draw(rendererContext.cgContext)
        } catch {
            captured = error
        }
    }
    if let captured { throw captured }
    return image
}
#else
private func render(size: CGSize, draw: (CGContext) throws -> Void) throws -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        throw ImageLoaderError.decodingFailed(URL(string: "demo://render")!)
    }
    try draw(ctx)
    return image
}
#endif
