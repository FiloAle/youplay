import SwiftUI

/// Full-page player that collapses into a mini player by dragging the video down, and back up.
///
/// Layers keep their full-page size and move only through transform and opacity, so the transition
/// causes no layout pass and the native video view is never resized.
struct PlayerOverlay: View {
	let tabBarInset: CGFloat

	@Environment(PlayerModel.self) private var player

	@State private var progress: CGFloat = 1
	@State private var target: CGFloat = 1
	@State private var dragStart: CGFloat = 1
	// Expensive native changes (controls, video gravity) wait for the animation to end.
	@State private var isSettledExpanded = false
	@State private var presented = PresentedProgress()

	var body: some View {
		GeometryReader { proxy in
			let geometry = PlayerGeometry(
				size: CGSize(
					width: proxy.size.width,
					height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
				),
				safeTop: proxy.safeAreaInsets.top,
				miniBottom: tabBarInset + Spacing.sm
			)
			if let video = player.current {
				layers(video: video, geometry: geometry)
					.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
					.ignoresSafeArea()
			}
		}
		// Skipped when a gesture already started this spring, which would otherwise restart with no velocity.
		.onChange(of: player.isExpanded) {
			let value: CGFloat = player.isExpanded ? 0 : 1
			if target != value { spring(to: value) }
		}
	}

	private func layers(video: Video, geometry: PlayerGeometry) -> some View {
		ZStack(alignment: .topLeading) {
			Palette.background
				.frame(width: geometry.size.width, height: geometry.size.height)
				.modifier(PlayerBackdropEffect(progress: progress))
				.allowsHitTesting(false)

			PlayerDetails(video: video)
				.frame(width: geometry.size.width, height: geometry.size.height - geometry.detailsTop)
				.modifier(PlayerDetailsEffect(progress: progress, geometry: geometry))
				.allowsHitTesting(player.isExpanded)

			// Keeps the area above the video draggable.
			Color.clear
				.frame(width: geometry.size.width, height: geometry.safeTop)
				.contentShape(.rect)
				.gesture(pan(geometry))
				.allowsHitTesting(player.isExpanded)

			// Its own layer, because a shadow on the video would be redrawn on every frame of the transition.
			RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
				.fill(Palette.videoBackground)
				.shadow(color: Palette.shadow, radius: Metrics.shadowRadius, y: Spacing.xs)
				.frame(width: PlayerGeometry.miniVideoWidth, height: PlayerGeometry.miniVideoHeight)
				.modifier(PlayerMiniEffect(progress: progress, geometry: geometry))
				.allowsHitTesting(false)

			PlayerSurface(stage: player.stage, isExpanded: isSettledExpanded)
				// Only the video is clipped: the progress bar sits on its bottom edge.
				.modifier(PlayerVideoClip(progress: progress, geometry: geometry))
				.overlay {
					if !player.isExpanded {
						Color.clear
							.contentShape(.rect)
							.onTapGesture { player.isExpanded = true }
					} else if isSettledExpanded {
						PlayerControls(isFullScreen: false)
							.transition(.opacity)
					}
				}
				.animation(Motion.standard, value: isSettledExpanded)
				.frame(width: geometry.size.width, height: geometry.videoHeight)
				.gesture(pan(geometry))
				.modifier(PlayerVideoEffect(progress: progress, geometry: geometry, presented: presented))

			MiniPlayerControls()
				.frame(width: PlayerGeometry.miniVideoWidth, height: PlayerGeometry.miniVideoHeight)
				.gesture(pan(geometry))
				.modifier(PlayerMiniEffect(progress: progress, geometry: geometry))
				.allowsHitTesting(!player.isExpanded)
		}
	}

	private func pan(_ geometry: PlayerGeometry) -> VerticalPan {
		VerticalPan {
			FrameProbe.shared.start("drag")
			dragStart = presented.value
			moveWithoutAnimation(to: dragStart)
		} onChanged: { translation in
			moveWithoutAnimation(to: min(1, max(0, dragStart + translation / geometry.miniTop)))
		} onEnded: { velocity in
			let value: CGFloat
			if abs(velocity) > 500 {
				value = velocity > 0 ? 1 : 0
			} else {
				value = progress > 0.5 ? 1 : 0
			}
			spring(to: value, velocity: velocity / geometry.miniTop)
			player.isExpanded = value == 0
		}
	}

	private func moveWithoutAnimation(to value: CGFloat) {
		var transaction = Transaction()
		transaction.disablesAnimations = true
		withTransaction(transaction) { progress = value }
	}

	private func spring(to value: CGFloat, velocity: CGFloat = 0) {
		FrameProbe.shared.start(value == 0 ? "expand" : "collapse")
		target = value
		withAnimation(Motion.player(velocity: velocity)) {
			progress = value
		} completion: {
			FrameProbe.shared.stop()
			if target == value { isSettledExpanded = value == 0 }
		}
	}
}
