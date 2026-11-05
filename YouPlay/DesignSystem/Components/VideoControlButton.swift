import SwiftUI

/// Icon in a Liquid Glass circle, readable on top of any video, with a 44 pt touch target.
/// `.controlSize(.large)` makes it bigger, for full screen.
struct VideoControlButton: View {
	let systemName: String
	let label: String
	var emphasis = VideoControlEmphasis.standard
	let action: () -> Void

	@Environment(\.isEnabled) private var isEnabled
	@Environment(\.controlSize) private var controlSize

	var body: some View {
		Button(action: action) {
			VideoControlCircle(emphasis: emphasis) {
				Image(systemName: systemName)
					.font(emphasis.font(isLarge: controlSize >= .large))
					.foregroundStyle(Palette.badgeText)
					.opacity(isEnabled ? 1 : Metrics.disabledOpacity)
					.contentTransition(.symbolEffect(.replace))
			}
		}
		.buttonStyle(.plain)
		.accessibilityLabel(label)
	}
}

/// How much a control stands out: the main action, the ones beside it, and everything else.
enum VideoControlEmphasis {
	/// Options, queue, full screen: at the video's edges.
	case standard
	/// Skipping, next to the main action.
	case secondary
	/// Play and pause, in the middle of the video.
	case primary

	func diameter(isLarge: Bool) -> CGFloat {
		switch (self, isLarge) {
		case (.standard, false): Metrics.videoControl
		case (.standard, true): Metrics.largeVideoControl
		case (.secondary, false): Metrics.secondaryVideoControl
		case (.secondary, true): Metrics.largeSecondaryVideoControl
		case (.primary, false): Metrics.prominentVideoControl
		case (.primary, true): Metrics.largeProminentVideoControl
		}
	}

	func font(isLarge: Bool) -> Font {
		switch (self, isLarge) {
		case (.standard, false): Typography.videoControl
		case (.standard, true): Typography.largeVideoControl
		case (.secondary, false): Typography.secondaryVideoControl
		case (.secondary, true): Typography.largeSecondaryVideoControl
		case (.primary, false): Typography.prominentVideoControl
		case (.primary, true): Typography.largeProminentVideoControl
		}
	}
}

struct VideoControlCircle<Content: View>: View {
	var emphasis = VideoControlEmphasis.standard
	@ViewBuilder let content: Content

	@Environment(\.controlSize) private var controlSize

	var body: some View {
		let diameter = emphasis.diameter(isLarge: controlSize >= .large)
		content
			.frame(width: diameter, height: diameter)
			.glassEffect(.regular.interactive(), in: .circle)
			.frame(width: max(diameter, Metrics.minimumTouchTarget), height: max(diameter, Metrics.minimumTouchTarget))
			.contentShape(.rect)
	}
}
