// Renders AppIconScene to a 1024×1024 PNG. Run via `make icon`;
// macOS-only tooling.
//
// App Store Connect rejects app icons that carry an alpha channel — a
// transparent icon silently never shows up. ImageRenderer.cgImage is
// always RGBA, even for a scene that fills its frame, so the image is
// redrawn onto an opaque bitmap before writing.

#if os(macOS)
import CoreGraphics
import ImageIO
import PhotoDiaryKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
func flattened(_ image: CGImage) -> CGImage {
    let side = image.width
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else {
        fatalError("cannot create opaque icon context")
    }
    let rect = CGRect(x: 0, y: 0, width: side, height: side)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    guard let opaque = context.makeImage() else {
        fatalError("cannot flatten icon to an opaque image")
    }
    return opaque
}

@MainActor
func renderIcon() {
    let side: CGFloat = 1024
    let renderer = ImageRenderer(content: AppIconScene().frame(width: side, height: side))
    renderer.proposedSize = ProposedViewSize(width: side, height: side)
    renderer.scale = 1
    guard let image = renderer.cgImage else {
        fatalError("icon render produced no image")
    }
    let opaque = flattened(image)
    let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
    let url = URL(fileURLWithPath: path)
    guard
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        fatalError("cannot open \(path) for writing")
    }
    CGImageDestinationAddImage(destination, opaque, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("failed to finalize \(path)")
    }
    print("wrote \(url.path)")
}

await MainActor.run { renderIcon() }
#endif
