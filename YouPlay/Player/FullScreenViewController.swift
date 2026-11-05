import AVFoundation
import SwiftUI

/// Full-screen video in landscape, while the rest of the app stays in portrait.
/// Presenting it turns the scene, and the transition carries the video from its place in the page
/// to the whole screen, turning and growing in one motion. Dragging the video down closes it.
final class FullScreenViewController: UIViewController {
	private let videoView: VideoView
	private weak var inlineContainer: UIView?
	private let controls: UIHostingController<AnyView>
	private let onExit: () -> Void
	private let orientation: UIInterfaceOrientation
	private let backdrop = UIView()

	init(videoView: VideoView, inlineContainer: UIView, controls: some View, onExit: @escaping () -> Void) {
		self.videoView = videoView
		self.inlineContainer = inlineContainer
		self.controls = UIHostingController(rootView: AnyView(controls))
		self.onExit = onExit
		// The side the phone is already turned to, otherwise the usual one. Device and interface sides are opposite.
		orientation = UIDevice.current.orientation == .landscapeRight ? .landscapeLeft : .landscapeRight
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .fullScreen
		transitioningDelegate = self
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError()
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
	override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { orientation }
	override var prefersStatusBarHidden: Bool { true }
	override var prefersHomeIndicatorAutoHidden: Bool { true }

	override func viewDidLoad() {
		super.viewDidLoad()
		backdrop.backgroundColor = UIColor(Palette.videoBackground)
		backdrop.frame = view.bounds
		backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(backdrop)

		addChild(controls)
		controls.view.backgroundColor = .clear
		controls.view.frame = view.bounds
		controls.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(controls.view)
		controls.didMove(toParent: self)

		let pan = UIPanGestureRecognizer(target: self, action: #selector(drag))
		pan.delegate = self
		view.addGestureRecognizer(pan)
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if isBeingDismissed { onExit() }
	}

	// MARK: Poses

	/// Where the video is in the page, in this view's coordinates: the page is turned while this is on screen.
	fileprivate var inlinePose: VideoPose {
		guard let inlineContainer else { return .rest(in: view.bounds) }
		let bounds = inlineContainer.bounds
		let origin = inlineContainer.convert(CGPoint(x: bounds.minX, y: bounds.minY), to: view)
		let edge = inlineContainer.convert(CGPoint(x: bounds.maxX, y: bounds.minY), to: view)
		let center = inlineContainer.convert(CGPoint(x: bounds.midX, y: bounds.midY), to: view)
		let scale = hypot(edge.x - origin.x, edge.y - origin.y) / max(bounds.width, 1)
		let inline = fittedVideo(in: CGSize(width: bounds.width * scale, height: bounds.height * scale))
		let full = fittedVideo(in: view.bounds.size)
		return VideoPose(
			center: center,
			angle: atan2(edge.y - origin.y, edge.x - origin.x),
			scale: inline.width / max(full.width, 1)
		)
	}

	fileprivate var currentPose: VideoPose {
		guard videoView.superview === view else { return .rest(in: view.bounds) }
		let transform = videoView.transform
		return VideoPose(center: videoView.center, angle: atan2(transform.b, transform.a), scale: hypot(transform.a, transform.b))
	}

	private func fittedVideo(in size: CGSize) -> CGSize {
		let video = videoView.playerLayer.player?.currentItem?.presentationSize ?? .zero
		return AVMakeRect(aspectRatio: video == .zero ? CGSize(width: 16, height: 9) : video, insideRect: CGRect(origin: .zero, size: size)).size
	}

	fileprivate func showVideo(at pose: VideoPose) {
		if videoView.superview !== view {
			videoView.autoresizingMask = []
			videoView.transform = .identity
			view.insertSubview(videoView, aboveSubview: backdrop)
		}
		videoView.playerLayer.videoGravity = .resizeAspect
		videoView.bounds = CGRect(origin: .zero, size: view.bounds.size)
		videoView.center = pose.center
		videoView.transform = CGAffineTransform(rotationAngle: pose.angle).scaledBy(x: pose.scale, y: pose.scale)
	}

	/// Settles the video at rest, where rotations of the scene keep it filling the screen.
	fileprivate func settleVideo() {
		videoView.place(in: view)
		view.insertSubview(videoView, aboveSubview: backdrop)
	}

	fileprivate func setChrome(alpha: CGFloat) {
		backdrop.alpha = alpha
		controls.view.alpha = alpha
	}

	// MARK: Drag to close

	@objc private func drag(_ pan: UIPanGestureRecognizer) {
		let translation = pan.translation(in: view)
		let progress = min(1, max(0, translation.y / view.bounds.height))
		switch pan.state {
		case .began:
			// The video moves on its own from here, so its autoresizing must not fight the drag.
			showVideo(at: .rest(in: view.bounds))
		case .changed:
			let rest = VideoPose.rest(in: view.bounds)
			showVideo(at: VideoPose(
				center: CGPoint(x: rest.center.x + translation.x, y: rest.center.y + max(0, translation.y)),
				angle: 0,
				scale: 1 - progress * 0.4
			))
			setChrome(alpha: 1 - progress)
			controls.view.alpha = 0
		case .ended, .cancelled:
			if pan.state == .ended, translation.y > 0, pan.velocity(in: view).y > 600 || progress > 0.2 {
				dismiss(animated: true)
			} else {
				UIView.animate(springDuration: Motion.transitionDuration, bounce: 0) {
					self.showVideo(at: .rest(in: self.view.bounds))
					self.setChrome(alpha: 1)
				} completion: { _ in
					self.settleVideo()
				}
			}
		default:
			break
		}
	}
}

extension FullScreenViewController: UIGestureRecognizerDelegate {
	/// Only a pull down closes, so that sideways drags keep scrubbing the video.
	func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
		guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
		let velocity = pan.velocity(in: view)
		return velocity.y > abs(velocity.x)
	}
}

extension FullScreenViewController: UIViewControllerTransitioningDelegate {
	func animationController(
		forPresented presented: UIViewController,
		presenting: UIViewController,
		source: UIViewController
	) -> (any UIViewControllerAnimatedTransitioning)? {
		FullScreenTransition(isPresenting: true)
	}

	func animationController(forDismissed dismissed: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
		FullScreenTransition(isPresenting: false)
	}
}

/// The video's place as a transform of a view the size of the screen.
fileprivate struct VideoPose {
	let center: CGPoint
	let angle: CGFloat
	let scale: CGFloat

	static func rest(in bounds: CGRect) -> VideoPose {
		VideoPose(center: CGPoint(x: bounds.midX, y: bounds.midY), angle: 0, scale: 1)
	}
}

private final class FullScreenTransition: NSObject, UIViewControllerAnimatedTransitioning {
	let isPresenting: Bool

	init(isPresenting: Bool) {
		self.isPresenting = isPresenting
	}

	func transitionDuration(using context: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
		Motion.transitionDuration
	}

	func animateTransition(using context: any UIViewControllerContextTransitioning) {
		if isPresenting { present(using: context) } else { dismiss(using: context) }
	}

	private func present(using context: any UIViewControllerContextTransitioning) {
		guard let fullScreen = context.viewController(forKey: .to) as? FullScreenViewController else {
			context.completeTransition(false)
			return
		}
		fullScreen.view.frame = context.finalFrame(for: fullScreen)
		context.containerView.addSubview(fullScreen.view)
		fullScreen.view.layoutIfNeeded()
		fullScreen.showVideo(at: fullScreen.inlinePose)
		fullScreen.setChrome(alpha: 0)

		UIView.animate(springDuration: Motion.transitionDuration, bounce: 0) {
			fullScreen.showVideo(at: .rest(in: fullScreen.view.bounds))
			fullScreen.setChrome(alpha: 1)
		} completion: { _ in
			fullScreen.settleVideo()
			context.completeTransition(!context.transitionWasCancelled)
		}
	}

	private func dismiss(using context: any UIViewControllerContextTransitioning) {
		guard
			let fullScreen = context.viewController(forKey: .from) as? FullScreenViewController,
			let page = context.viewController(forKey: .to)
		else {
			context.completeTransition(false)
			return
		}
		page.view.frame = context.finalFrame(for: page)
		context.containerView.insertSubview(page.view, belowSubview: fullScreen.view)
		page.view.layoutIfNeeded()
		// From wherever the video is: a drag may have moved it.
		fullScreen.showVideo(at: fullScreen.currentPose)

		UIView.animate(springDuration: Motion.transitionDuration, bounce: 0) {
			fullScreen.showVideo(at: fullScreen.inlinePose)
			fullScreen.setChrome(alpha: 0)
		} completion: { _ in
			context.completeTransition(!context.transitionWasCancelled)
		}
	}
}
