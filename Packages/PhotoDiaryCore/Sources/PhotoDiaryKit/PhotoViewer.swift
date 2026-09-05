import SwiftUI

/// A full-viewport photo with pinch-to-zoom, pan, and double-tap-zoom.
/// Chrome (close button, metadata panel) is layered on top by
/// callers — this view is just the image + gestures.
///
/// Zoom is clamped to [1, maxZoom]. At 1×, pan is disabled (SwiftUI
/// still lets you drag the sheet dismissal). Above 1×, pan is bounded
/// so the image can't leave the viewport.
public struct PhotoViewer: View {
    private let image: PlatformImage
    private let maxZoom: CGFloat = 4.0

    @State private var zoom: CGFloat = 1.0
    @State private var committedZoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero

    public init(image: PlatformImage) {
        self.image = image
    }

    public var body: some View {
        GeometryReader { geometry in
            Color.black
                .overlay(
                    swiftUIImage
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom)
                        .offset(pan)
                        .gesture(zoomGesture)
                        .simultaneousGesture(panGesture(in: geometry.size))
                        .onTapGesture(count: 2) { toggleDoubleTapZoom() }
                        .animation(.easeInOut(duration: 0.2), value: zoom)
                        .animation(.easeInOut(duration: 0.2), value: pan)
                )
                .ignoresSafeArea()
        }
    }

    private var swiftUIImage: Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = clamp(committedZoom * value, min: 1, max: maxZoom)
            }
            .onEnded { _ in
                committedZoom = zoom
                if zoom == 1 {
                    pan = .zero
                    committedPan = .zero
                }
            }
    }

    private func panGesture(in viewport: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoom > 1 else { return }
                let proposed = CGSize(
                    width: committedPan.width + value.translation.width,
                    height: committedPan.height + value.translation.height
                )
                pan = clampPan(proposed, viewport: viewport)
            }
            .onEnded { _ in
                committedPan = pan
            }
    }

    private func toggleDoubleTapZoom() {
        if zoom > 1 {
            zoom = 1
            committedZoom = 1
            pan = .zero
            committedPan = .zero
        } else {
            zoom = 2
            committedZoom = 2
        }
    }

    private func clampPan(_ proposed: CGSize, viewport: CGSize) -> CGSize {
        // At zoom Z, the scaled image sticks (Z-1)/2 × viewport past
        // each edge — anything further would show black borders. Cap
        // pan to that slack.
        let slackX = max(0, (zoom - 1) * viewport.width / 2)
        let slackY = max(0, (zoom - 1) * viewport.height / 2)
        return CGSize(
            width: clamp(proposed.width, min: -slackX, max: slackX),
            height: clamp(proposed.height, min: -slackY, max: slackY)
        )
    }
}

private func clamp<T: Comparable>(_ value: T, min lower: T, max upper: T) -> T {
    min(max(value, lower), upper)
}
