import SwiftUI

/// Short text on top of a video or its image: duration, scheduled time, or live in red.
struct VideoBadge: View {
	let text: String
	var isLive = false
	var isCompact = false

	var body: some View {
		Text(text)
			.font(Typography.badge)
			.foregroundStyle(Palette.badgeText)
			.padding(.horizontal, isCompact ? Spacing.xs : Spacing.sm)
			.padding(.vertical, isCompact ? Spacing.xxs : Spacing.xs)
			.background(isLive ? Palette.accent : Palette.badgeBackground, in: .rect(cornerRadius: Radius.sm, style: .continuous))
	}
}

extension VideoBadge {
	static let liveText = "DAL VIVO"
}
