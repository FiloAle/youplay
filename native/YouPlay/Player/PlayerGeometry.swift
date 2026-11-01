import SwiftUI

/// Where every player layer sits, as a function of `progress`: 0 is full page, 1 is mini player.
struct PlayerGeometry {
	static let miniMargin = Spacing.lg
	static let miniVideoWidth: CGFloat = 192
	static let miniVideoHeight = miniVideoWidth * 9 / 16

	let size: CGSize
	let safeTop: CGFloat
	/// Distance of the mini player from the bottom of the screen, above the tab bar.
	let miniBottom: CGFloat

	var videoHeight: CGFloat { size.width * 9 / 16 }
	var miniTop: CGFloat { size.height - miniBottom - Self.miniVideoHeight }
	var miniLeft: CGFloat { size.width - Self.miniMargin - Self.miniVideoWidth }
	var miniVideoScale: CGFloat { Self.miniVideoWidth / size.width }
	var detailsTop: CGFloat { safeTop + videoHeight }

	func videoScale(at progress: CGFloat) -> CGFloat {
		interpolate(progress, from: 1, to: miniVideoScale)
	}

	func videoOrigin(at progress: CGFloat) -> CGPoint {
		CGPoint(
			x: interpolate(progress, from: 0, to: miniLeft),
			y: interpolate(progress, from: safeTop, to: miniTop)
		)
	}
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
		let origin = geometry.videoOrigin(at: progress)
		// The corners get scaled along with the video, so the radius is set at full size.
		let radius = interpolate(progress, from: 0, to: Radius.lg / geometry.miniVideoScale)
		return content
			.clipShape(.rect(cornerRadius: radius, style: .continuous))
			.scaleEffect(geometry.videoScale(at: progress), anchor: .topLeading)
			.offset(x: origin.x, y: origin.y)
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
		content
			.scaleEffect(
				x: geometry.videoScale(at: progress),
				y: interpolate(progress, from: 1, to: PlayerGeometry.miniVideoHeight / geometry.size.height),
				anchor: .topLeading
			)
			.offset(
				x: interpolate(progress, from: 0, to: geometry.miniLeft),
				y: interpolate(progress, from: 0, to: geometry.miniTop)
			)
			.opacity(interpolate(progress, in: 0.75...0.98, from: 1, to: 0))
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

/// Mini player layers: they follow the video exactly, and appear as it gets to its final size.
struct PlayerMiniEffect: ViewModifier, Animatable {
	var progress: CGFloat
	let geometry: PlayerGeometry

	nonisolated var animatableData: CGFloat {
		get { progress }
		set { progress = newValue }
	}

	func body(content: Content) -> some View {
		let origin = geometry.videoOrigin(at: progress)
		return content
			.opacity(interpolate(progress, in: 0.7...1, from: 0, to: 1))
			.scaleEffect(geometry.videoScale(at: progress) / geometry.miniVideoScale, anchor: .topLeading)
			.offset(x: origin.x, y: origin.y)
	}
}
