import AVKit

/// Moves the video in and out of full screen in one motion, in place of AVKit's animation, which can't handle
/// a portrait app: it rotates after growing, jumps when the finger lifts and lands at the wrong size.
/// AVKit still runs its transition, hidden, while a second layer on the same player does the flying.
@MainActor
final class FullScreenFlight {
	private var videoView: FlightVideoView?
	private var backdrop: UIView?
	private var rotationObserver: RotationObserver?
	private weak var scene: UIWindowScene?
	private var side = UIInterfaceOrientation.landscapeRight
	private var inlineFrame = CGRect.zero

	func enter(from controller: AVPlayerViewController, with coordinator: any UIViewControllerTransitionCoordinator) {
		scene = controller.view.window?.windowScene
		side = UIDevice.current.orientation == .landscapeRight ? .landscapeLeft : .landscapeRight
		let frame = controller.view.convert(controller.view.bounds, to: nil)
		// With the phone already on its side, the scene has turned by now, while the page stays in portrait.
		let isTurning = frame.height > frame.width
		inlineFrame = isTurning ? portraitFrame(of: frame, in: controller.view.window) : frame
		let turnedAngle: CGFloat = side == .landscapeRight ? .pi / 2 : -.pi / 2

		coordinator.animate { [self] context in
			guard let window = context.containerView.window, let player = controller.player, let fullScreen = context.viewController(forKey: .to) else { return }
			observeRotation(of: fullScreen)
			let size = videoSize(of: player, in: window)
			UIView.performWithoutAnimation {
				fullScreen.view.alpha = 0
				let page = FlightPose(fitting: inlineFrame, videoSize: size)
				let start = isTurning ? FlightPose(center: CGPoint(x: frame.midX, y: frame.midY), angle: -turnedAngle, scale: page.scale) : page
				launch(player, in: window, size: size, from: start)
			}
			let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
			videoView?.apply(FlightPose(center: center, angle: isTurning ? 0 : turnedAngle, scale: 1))
		} completion: { [self] context in
			let fullScreen = context.viewController(forKey: .to)
			if context.isCancelled {
				land(fullScreen)
			} else {
				rotate(into: fullScreen)
			}
		}
	}

	func exit(from controller: AVPlayerViewController, with coordinator: any UIViewControllerTransitionCoordinator) {
		if coordinator.isInteractive {
			// The finger moves AVKit's own video. The flight takes over from where it is when the finger lifts.
			coordinator.notifyWhenInteractionChanges { [self] context in
				guard let window = context.containerView.window, let player = controller.player, let fullScreen = context.viewController(forKey: .from) else { return }
				let start = FlightPose(of: fullScreen.view)
				let size = videoSize(of: player, in: window)
				UIView.performWithoutAnimation {
					fullScreen.view.alpha = 0
					launch(player, in: window, size: size, from: start)
				}
				let target = context.isCancelled
					? FlightPose(center: CGPoint(x: window.bounds.midX, y: window.bounds.midY), angle: start.angle, scale: 1)
					: FlightPose(fitting: inlineFrame, videoSize: size)
				let remaining = context.transitionDuration * (context.isCancelled ? context.percentComplete : 1 - context.percentComplete)
				UIView.animate(withDuration: remaining, delay: 0, options: .curveEaseOut) { self.videoView?.apply(target) }
				if context.isCancelled {
					// iOS turns the scene back on its own, before the transition ends.
					landAfterRotating(fullScreen)
				}
			}
		} else {
			coordinator.animate { [self] context in
				guard let window = context.containerView.window, let player = controller.player, let fullScreen = context.viewController(forKey: .from) else { return }
				let size = videoSize(of: player, in: window)
				UIView.performWithoutAnimation {
					launch(player, in: window, size: size, from: FlightPose(of: fullScreen.view))
					fullScreen.view.alpha = 0
				}
				videoView?.apply(FlightPose(fitting: inlineFrame, videoSize: size))
			}
		}
		coordinator.animate(alongsideTransition: nil) { [self] context in
			if !context.isCancelled {
				land(context.viewController(forKey: .from))
			}
		}
	}

	private func portraitFrame(of frame: CGRect, in window: UIWindow?) -> CGRect {
		let bounds = window?.bounds ?? .zero
		let turnedRight = side == .landscapeRight
		return CGRect(
			x: turnedRight ? bounds.height - frame.maxY : frame.minY,
			y: turnedRight ? frame.minX : bounds.width - frame.maxX,
			width: frame.height,
			height: frame.width
		)
	}

	/// iOS refuses this until the transition has ended: it still goes by the screen below, which is portrait only.
	private func rotate(into fullScreen: UIViewController?) {
		guard let scene, let window = videoView?.superview, window.bounds.height > window.bounds.width else {
			land(fullScreen)
			return
		}
		landAfterRotating(fullScreen)
		scene.requestGeometryUpdate(.iOS(interfaceOrientations: side == .landscapeRight ? .landscapeRight : .landscapeLeft))
	}

	private func landAfterRotating(_ fullScreen: UIViewController?) {
		rotationObserver?.didRotate = { [self] in land(fullScreen) }
		// Whatever iOS does, the real video must not stay hidden.
		let videoView = videoView
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
			if self.videoView === videoView {
				land(fullScreen)
			}
		}
	}

	private func videoSize(of player: AVPlayer, in window: UIWindow) -> CGSize {
		let bounds = window.bounds
		let screen = CGRect(x: 0, y: 0, width: max(bounds.width, bounds.height), height: min(bounds.width, bounds.height))
		let video = player.currentItem?.presentationSize ?? .zero
		return AVMakeRect(aspectRatio: video == .zero ? inlineFrame.size : video, insideRect: screen).size
	}

	private func launch(_ player: AVPlayer, in window: UIWindow, size: CGSize, from pose: FlightPose) {
		let view = FlightVideoView(player: player, size: size)
		view.apply(pose)
		window.addSubview(view)
		videoView = view
	}

	/// The video is already in place, so the scene's rotation mustn't show: it turns the other way around the same point.
	/// AVKit adds a copy of its video during a rotation, which the backdrop hides.
	private func holdStill(duringRotationTo size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
		guard let videoView, let window = videoView.superview else { return }
		let longSide = max(size.width, size.height)
		let backdrop = UIView(frame: CGRect(x: -longSide, y: -longSide, width: 3 * longSide, height: 3 * longSide))
		backdrop.backgroundColor = .black
		window.insertSubview(backdrop, belowSubview: videoView)
		self.backdrop = backdrop

		let angle = atan2(videoView.transform.b, videoView.transform.a)
		let pivotOffset = (angle > 0 ? min(size.width, size.height) : longSide) / 2
		let end = CGPoint(x: size.width / 2, y: size.height / 2)
		UIView.performWithoutAnimation {
			videoView.layer.anchorPoint = CGPoint(
				x: 0.5 + (pivotOffset - end.x) / videoView.bounds.width,
				y: 0.5 + (pivotOffset - end.y) / videoView.bounds.height
			)
			videoView.center = CGPoint(x: pivotOffset, y: pivotOffset)
			videoView.transform = CGAffineTransform(rotationAngle: angle)
		}
		coordinator.animate { _ in videoView.transform = .identity }
	}

	private func land(_ fullScreen: UIViewController?) {
		fullScreen?.view.alpha = 1
		videoView?.removeFromSuperview()
		videoView = nil
		backdrop?.removeFromSuperview()
		backdrop = nil
		rotationObserver?.didRotate = nil
	}

	private func observeRotation(of fullScreen: UIViewController) {
		rotationObserver?.removeFromParent()
		let observer = RotationObserver()
		observer.willRotate = { [weak self] size, coordinator in
			self?.holdStill(duringRotationTo: size, with: coordinator)
		}
		fullScreen.addChild(observer)
		fullScreen.view.addSubview(observer.view)
		observer.didMove(toParent: fullScreen)
		rotationObserver = observer
	}
}

private struct FlightPose {
	let center: CGPoint
	let angle: CGFloat
	let scale: CGFloat

	init(center: CGPoint, angle: CGFloat, scale: CGFloat) {
		self.center = center
		self.angle = angle
		self.scale = scale
	}

	/// The video unrotated in a frame of the page.
	init(fitting frame: CGRect, videoSize: CGSize) {
		center = CGPoint(x: frame.midX, y: frame.midY)
		angle = 0
		scale = min(frame.width / videoSize.width, frame.height / videoSize.height)
	}

	/// Where AVKit has its own view now, which it moves only by transform.
	@MainActor
	init(of view: UIView) {
		let layer = view.layer.presentation() ?? view.layer
		let transform = layer.affineTransform()
		center = CGPoint(x: layer.position.x + transform.tx, y: layer.position.y + transform.ty)
		angle = atan2(transform.b, transform.a)
		scale = hypot(transform.a, transform.b)
	}
}

private final class FlightVideoView: UIView {
	override class var layerClass: AnyClass { AVPlayerLayer.self }

	init(player: AVPlayer, size: CGSize) {
		super.init(frame: CGRect(origin: .zero, size: size))
		isUserInteractionEnabled = false
		(layer as? AVPlayerLayer)?.player = player
		(layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError()
	}

	func apply(_ pose: FlightPose) {
		center = pose.center
		transform = CGAffineTransform(rotationAngle: pose.angle).scaledBy(x: pose.scale, y: pose.scale)
	}
}

/// A view controller is the only way to hear about a rotation and join its animation.
private final class RotationObserver: UIViewController {
	var willRotate: ((CGSize, any UIViewControllerTransitionCoordinator) -> Void)?
	var didRotate: (() -> Void)?

	override func loadView() {
		view = UIView(frame: .zero)
		view.isHidden = true
	}

	override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		// Cancelling a swipe first goes through portrait, without showing it.
		guard didRotate != nil, size.width > size.height else { return }
		willRotate?(size, coordinator)
		coordinator.animate(alongsideTransition: nil) { [weak self] _ in
			self?.didRotate?()
		}
	}
}
