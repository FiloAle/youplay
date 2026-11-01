import SwiftUI

/// Where every player layer sits, as a function of `progress`: 0 is full page, 1 is mini player.
struct PlayerGeometry {
	static let miniHeight: CGFloat = 64
	static let miniMargin: CGFloat = Spacing.sm
	static let miniVideoWidth: CGFloat = 100

	let size: CGSize
	let safeTop: CGFloat
	/// Distance of the mini player from the bottom of the screen, above the tab bar.
	let miniBottom: CGFloat

	var videoHeight: CGFloat { size.width * 9 / 16 }
	var miniTop: CGFloat { size.height - miniBottom - Self.miniHeight }
	var miniVideoScale: CGFloat { Self.miniVideoWidth / size.width }
	var miniVideoHeight: CGFloat { Self.miniVideoWidth * 9 / 16 }
	var detailsTop: CGFloat { safeTop + videoHeight }
}

/// Linear from `from` to `to` while `progress` goes through `range`, clamped outside of it.
func interpolate(_ progress: CGFloat, in range: ClosedRange<CGFloat> = 0...1, from: CGFloat, to: CGFloat) -> CGFloat {
	let t = min(1, max(0, (progress - range.lowerBound) / (range.upperBound - range.lowerBound)))
	return from + (to - from) * t
}

/// The value `progress` currently has on screen, which differs from the model during an animation.
/// Lets a drag grab the player mid-flight without a jump.
final class PresentedProgress {
	var value: CGFloat = 1
}

/// Base for the layer effects: SwiftUI calls `body` with the interpolated `progress` on every frame.
struct PlayerVideoEffect: ViewModifier, Animatable {
	var progress: CGFloat
	let geometry: PlayerGeometry
	let presented: PresentedProgress

	nonisolated var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func body(content: Content) -> some View {
		presented.value = progress
		let scale = interpolate(progress, from: 1, to: geometry.miniVideoScale)
		// The corners get scaled along with the video, so the radius is set at full size.
		let radius = interpolate(progress, from: 0, to: Radius.md / geometry.miniVideoScale)
		return content
			.clipShape(.rect(cornerRadius: radius, style: .continuous))
			.scaleEffect(scale, anchor: .topLeading)
			.offset(
				x: interpolate(progress, from: 0, to: PlayerGeometry.miniMargin + Spacing.xs),
				y: interpolate(
					progress,
					from: geometry.safeTop,
					to: geometry.miniTop + (PlayerGeometry.miniHeight - geometry.miniVideoHeight) / 2
				)
			)
	}
}

struct PlayerBackdropEffect: ViewModifier, Animatable {
	var progress: CGFloat
	let geometry: PlayerGeometry

	nonisolated var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func body(content: Content) -> some View {
		let width = geometry.size.width
		return content
			.scaleEffect(
				x: interpolate(progress, from: 1, to: (width - PlayerGeometry.miniMargin * 2) / width),
				y: interpolate(progress, from: 1, to: PlayerGeometry.miniHeight / geometry.size.height),
				anchor: .top
			)
			.offset(y: interpolate(progress, from: 0, to: geometry.miniTop))
			.opacity(interpolate(progress, in: 0.85...1, from: 1, to: 0))
	}
}

struct PlayerDetailsEffect: ViewModifier, Animatable {
	var progress: CGFloat
	let geometry: PlayerGeometry

	nonisolated var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func body(content: Content) -> some View {
		content
			.opacity(interpolate(progress, in: 0...0.3, from: 1, to: 0))
			.offset(y: geometry.detailsTop + interpolate(progress, from: 0, to: geometry.miniTop))
	}
}

struct PlayerMiniEffect: ViewModifier, Animatable {
	var progress: CGFloat
	let geometry: PlayerGeometry

	nonisolated var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func body(content: Content) -> some View {
		content
			.opacity(interpolate(progress, in: 0.7...1, from: 0, to: 1))
			.offset(
				x: PlayerGeometry.miniMargin,
				y: geometry.miniTop + interpolate(progress, in: 0.7...1, from: -0.3 * geometry.miniTop, to: 0)
			)
	}
}
