import SwiftUI

struct IconButton: View {
	let systemName: String
	let label: String
	let action: () -> Void

	var body: some View {
		Button(label, systemImage: systemName, action: action)
			.labelStyle(.iconOnly)
			.font(Typography.icon)
			.foregroundStyle(Palette.textPrimary)
			.frame(width: 44, height: 44)
			.contentShape(.rect)
			.buttonStyle(.plain)
	}
}

/// A secondary action's icon in a neutral circle. It's a label, so `Button` and `Menu` look the same.
struct CircleIcon: View {
	let systemName: String
	let label: String

	var body: some View {
		Image(systemName: systemName)
			.foregroundStyle(Palette.textPrimary)
			.frame(width: Metrics.circleIcon, height: Metrics.circleIcon)
			.background(Palette.surface, in: .circle)
			.frame(width: Metrics.minimumTouchTarget, height: Metrics.minimumTouchTarget)
			.contentShape(.rect)
			.accessibilityLabel(label)
	}
}
