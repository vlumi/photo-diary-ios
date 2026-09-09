import SwiftUI

/// The app icon, drawn: a lens framing a sunrise over a navy horizon.
/// Rendered to the 1024 px PNG in the asset catalog by `make icon`
/// (the photodiary-icon tool); kept in code so it can be regenerated
/// and reused, for the site's favicon among other things. Geometry is
/// in a 1024-unit space and scales to whatever frame it is given.
public struct AppIconScene: View {
    public static let navy = Color(red: 0x0A / 255, green: 0x1A / 255, blue: 0x4F / 255)
    public static let sky = Color(red: 0xBF / 255, green: 0xD7 / 255, blue: 0xFF / 255)
    public static let sun = Color(red: 0xF2 / 255, green: 0x8C / 255, blue: 0x28 / 255)

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let s = size.width / 1024
            let center = CGPoint(x: 512 * s, y: 512 * s)
            let horizon = 560 * s

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.navy))
            context.fill(circle(center, radius: 330 * s), with: .color(.white))
            context.fill(circle(center, radius: 262 * s), with: .color(Self.sky))
            context.fill(
                circle(CGPoint(x: center.x, y: horizon), radius: 120 * s), with: .color(Self.sun))
            // The sea: the part of the lens below the horizon.
            var below = Path()
            below.addRect(
                CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon))
            context.clip(to: circle(center, radius: 262 * s))
            context.fill(below, with: .color(Self.navy))
            context.stroke(
                circle(center, radius: 262 * s), with: .color(Self.navy), lineWidth: 24 * s)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(
                x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
