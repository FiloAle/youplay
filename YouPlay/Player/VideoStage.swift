import AVKit
import SwiftUI

/// Owns the only view that draws the video, and moves it between the page and full screen.
/// A single layer means the picture never goes blank or out of sync while it moves.
@MainActor
@Observable
final class VideoStage {
	private(set) var isFullScreen = false

	@ObservationIgnored let videoView: VideoView
	@ObservationIgnored private weak var inlineContainer: UIView?
	@ObservationIgnored private weak var fullScreen: FullScreenViewController?
	@ObservationIgnored private var pictureInPicture: AVPictureInPictureController?

	init(player: AVPlayer) {
		videoView = VideoView(player: player)
		if AVPictureInPictureController.isPictureInPictureSupported() {
			pictureInPicture = AVPictureInPictureController(playerLayer: videoView.playerLayer)
		}
	}

	var supportsPictureInPicture: Bool {
		pictureInPicture != nil
	}

	/// The page's slot for the video. The video goes back in it whenever it isn't in full screen.
	func attach(to container: UIView) {
		inlineContainer = container
		if !isFullScreen { videoView.place(in: container) }
	}

	func setInlineGravity(_ gravity: AVLayerVideoGravity) {
		guard !isFullScreen, videoView.playerLayer.videoGravity != gravity else { return }
		videoView.playerLayer.videoGravity = gravity
	}

	func enterFullScreen<Controls: View>(controls: Controls) {
		guard !isFullScreen, let inlineContainer, let presenter = inlineContainer.window?.rootViewController?.topPresented else { return }
		let controller = FullScreenViewController(videoView: videoView, inlineContainer: inlineContainer, controls: controls) { [weak self] in
			self?.didExitFullScreen()
		}
		fullScreen = controller
		isFullScreen = true
		presenter.present(controller, animated: true)
	}

	func exitFullScreen(animated: Bool = true) {
		fullScreen?.dismiss(animated: animated)
	}

	func startPictureInPicture() {
		pictureInPicture?.startPictureInPicture()
	}

	private func didExitFullScreen() {
		isFullScreen = false
		fullScreen = nil
		if let inlineContainer { videoView.place(in: inlineContainer) }
	}
}

/// Draws the player's video, and nothing else: whatever is behind it shows around the picture.
final class VideoView: UIView {
	override class var layerClass: AnyClass { AVPlayerLayer.self }

	var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

	init(player: AVPlayer) {
		super.init(frame: .zero)
		isUserInteractionEnabled = false
		playerLayer.player = player
		playerLayer.videoGravity = .resizeAspect
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError()
	}

	/// Fills `container`, at rest.
	func place(in container: UIView) {
		transform = .identity
		container.addSubview(self)
		frame = container.bounds
		autoresizingMask = [.flexibleWidth, .flexibleHeight]
	}
}

private extension UIViewController {
	var topPresented: UIViewController {
		presentedViewController?.topPresented ?? self
	}
}
