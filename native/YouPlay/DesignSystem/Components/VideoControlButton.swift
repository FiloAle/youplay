import SwiftUI

/// Icon in a dark circle, readable on top of any video, with a 44 pt touch target.
struct VideoControlButton: View {
	let systemName: String
	let label: String
	let action: () -> Void

	@Environment(\.isEnabled) private var isEnabled

	var body: some View {
		Button(action: action) {
			VideoControlCircle {
				Image(systemName: systemName)
					.font(Typography.videoControl)
					.foregroundStyle(Palette.badgeText)
					.opacity(isEnabled ? 1 : Metrics.disabledOpacity)
			}
		}
		.buttonStyle(RowButtonStyle())
		.accessibilityLabel(label)
	}
}

struct VideoControlCircle<Content: View>: View {
	@ViewBuilder let content: Content

	var body: some View {
		content
			.frame(width: Metrics.videoControl, height: Metrics.videoControl)
			.background(Palette.badgeBackground, in: .circle)
			.frame(width: Metrics.minimumTouchTarget, height: Metrics.minimumTouchTarget)
			.contentShape(.rect)
	}
}
