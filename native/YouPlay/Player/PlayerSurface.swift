import AVKit
import SwiftUI

/// The system video view. It keeps one size for its whole life: the player only ever scales it.
struct PlayerSurface: UIViewControllerRepresentable {
	let player: AVPlayer
	let isExpanded: Bool

	func makeUIViewController(context: Context) -> AVPlayerViewController {
		let controller = AVPlayerViewController()
		controller.player = player
		controller.delegate = context.coordinator
		controller.updatesNowPlayingInfoCenter = false
		controller.allowsVideoFrameAnalysis = false
		controller.view.backgroundColor = UIColor(Palette.videoBackground)
		update(controller)
		return controller
	}

	func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
		update(controller)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	private func update(_ controller: AVPlayerViewController) {
		if controller.showsPlaybackControls != isExpanded {
			controller.showsPlaybackControls = isExpanded
		}
		let gravity: AVLayerVideoGravity = isExpanded ? .resizeAspect : .resizeAspectFill
		if controller.videoGravity != gravity {
			controller.videoGravity = gravity
		}
	}

	@MainActor
	final class Coordinator: NSObject, @preconcurrency AVPlayerViewControllerDelegate {
		func playerViewController(
			_ controller: AVPlayerViewController,
			willBeginFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
		) {
			// The rotation only works once the full-screen controller is on screen.
			coordinator.animate(alongsideTransition: nil) { _ in
				OrientationLock.set(.landscape)
			}
		}

		func playerViewController(
			_ controller: AVPlayerViewController,
			willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
		) {
			OrientationLock.set(.portrait)
		}
	}
}
