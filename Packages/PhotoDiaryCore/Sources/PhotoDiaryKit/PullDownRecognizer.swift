#if canImport(UIKit)
import SwiftUI
import UIKit

/// A downward pan on the pager's scroll view, recognized at UIKit
/// level: a SwiftUI DragGesture inside a horizontal ScrollView never
/// sees a vertical drag, the scroll view claims it first. This pan is
/// added to that scroll view and begins only for a mostly vertical,
/// downward drag while `isEnabled`; the scroll view's own pan waits
/// for it to fail, which for a horizontal drag is immediate.
struct PullDownRecognizer: UIViewRepresentable {
    let isEnabled: () -> Bool
    let onChange: (CGFloat) -> Void
    let onEnd: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> AttachingView {
        let view = AttachingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: AttachingView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PullDownRecognizer

        init(parent: PullDownRecognizer) {
            self.parent = parent
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view).y
            switch recognizer.state {
            case .changed:
                parent.onChange(max(0, translation))
            case .ended, .cancelled, .failed:
                parent.onEnd(translation, recognizer.velocity(in: recognizer.view).y)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard parent.isEnabled(), let pan = recognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity = pan.velocity(in: pan.view)
            return velocity.y > 0 && velocity.y > abs(velocity.x) * 1.5
        }
    }

    /// Finds the enclosing scroll view once it is in a window and
    /// attaches the pan there.
    final class AttachingView: UIView {
        var coordinator: Coordinator?
        private var attached = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard !attached, let coordinator, let scrollView = enclosingScrollView() else { return }
            let pan = UIPanGestureRecognizer(
                target: coordinator, action: #selector(Coordinator.pan(_:)))
            pan.delegate = coordinator
            scrollView.addGestureRecognizer(pan)
            scrollView.panGestureRecognizer.require(toFail: pan)
            attached = true
        }

        private func enclosingScrollView() -> UIScrollView? {
            var view = superview
            while let current = view {
                if let scrollView = current as? UIScrollView { return scrollView }
                view = current.superview
            }
            return nil
        }
    }
}
#endif
