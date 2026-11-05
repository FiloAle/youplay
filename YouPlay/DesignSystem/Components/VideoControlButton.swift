import SwiftUI

/// Icon in a Liquid Glass circle, readable on top of any video, with a 44 pt touch target.
/// The prominent one is for the main action, in the middle of the video.
struct VideoControlButton: View {
	let systemName: String
	let label: String
	var isProminent = false
	let action: () -> Void

	@Environment(\.isEnabled) private var isEnabled

	var body: some View {
		Button(action: action) {
			VideoControlCircle(isProminent: isProminent) {
				Image(systemName: systemName)
					.font(isProminent ? Typography.prominentVideoControl : Typography.videoControl)
					.foregroundStyle(Palette.badgeText)
					.opacity(isEnabled ? 1 : Metrics.disabledOpacity)
					.contentTransition(.symbolEffect(.replace))
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel(label)
	}
}

struct VideoControlCircle<Content: View>: View {
	var isProminent = false
	@ViewBuilder let content: Content

	var body: some View {
		let diameter = isProminent ? Metrics.prominentVideoControl : Metrics.videoControl
		content
			.frame(width: diameter, height: diameter)
			.glassEffect(.regular.interactive(), in: .circle)
			.frame(width: max(diameter, Metrics.minimumTouchTarget), height: max(diameter, Metrics.minimumTouchTarget))
			.contentShape(.rect)
	}
}
