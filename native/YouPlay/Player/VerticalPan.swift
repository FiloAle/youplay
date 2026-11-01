import SwiftUI

/// A system pan that only starts on vertical movement, so horizontal scrubbing on the video keeps working.
struct VerticalPan: UIGestureRecognizerRepresentable {
	let onBegan: () -> Void
	let onChanged: (CGFloat) -> Void
	let onEnded: (CGFloat) -> Void

	final class Coordinator: NSObject, UIGestureRecognizerDelegate {
		func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
			guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
			let velocity = pan.velocity(in: nil)
			return abs(velocity.y) > abs(velocity.x)
		}

		func gestureRecognizer(
			_ recognizer: UIGestureRecognizer,
			shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
		) -> Bool {
			!(other is UIPanGestureRecognizer)
		}
	}

	func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
		Coordinator()
	}

	func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
		let recognizer = UIPanGestureRecognizer()
		recognizer.delegate = context.coordinator
		return recognizer
	}

	func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
		switch recognizer.state {
		case .began:
			onBegan()
		case .changed:
			onChanged(recognizer.translation(in: nil).y)
		case .ended, .cancelled:
			onEnded(recognizer.velocity(in: nil).y)
		default:
			break
		}
	}
}
