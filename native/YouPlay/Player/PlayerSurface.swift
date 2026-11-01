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
		private let flight = FullScreenFlight()

		func playerViewController(
			_ controller: AVPlayerViewController,
			willBeginFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
		) {
			flight.enter(from: controller, with: coordinator)
		}

		func playerViewController(
			_ controller: AVPlayerViewController,
			willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
		) {
			flight.exit(from: controller, with: coordinator)
			// AVKit pauses the player at the end of this transition, so a video that was playing gets resumed.
			let wasPlaying = controller.player?.timeControlStatus != .paused
			coordinator.animate(alongsideTransition: nil) { context in
				// A swipe that doesn't go through leaves the video in full screen, still playing.
				if wasPlaying && !context.isCancelled {
					DispatchQueue.main.async { controller.player?.play() }
				}
			}
		}
	}
}
