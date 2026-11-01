import SwiftUI

/// The only source of colors in the app. See DESIGN.md.
enum Palette {
	static let accent = Color(uiColor: .systemRed)
	static let background = Color(uiColor: .systemBackground)
	static let surface = Color(uiColor: .secondarySystemBackground)
	static let placeholder = Color(uiColor: .tertiarySystemFill)
	static let textPrimary = Color(uiColor: .label)
	static let textSecondary = Color(uiColor: .secondaryLabel)

	// Drawn on top of video and images, so they stay the same in both themes.
	static let videoBackground = Color.black
	static let badgeBackground = Color.black.opacity(0.7)
	static let badgeText = Color.white
}

enum Typography {
	static let channelName = Font.title2.bold()
	static let title = Font.title3.weight(.semibold)
	static let sectionTitle = Font.headline
	static let rowTitle = Font.subheadline.weight(.semibold)
	static let body = Font.subheadline
	static let metadata = Font.footnote
	static let badge = Font.caption2.weight(.semibold).monospacedDigit()
	static let icon = Font.title3
}

enum Spacing {
	static let xs: CGFloat = 4
	static let sm: CGFloat = 8
	static let md: CGFloat = 12
	static let lg: CGFloat = 16
}

enum Metrics {
	static let thumbnailWidth: CGFloat = 136
	static let avatar: CGFloat = 44
	static let channelAvatar: CGFloat = 96
	static let minimumTouchTarget: CGFloat = 44
	static let circleIcon: CGFloat = 36
}

enum Radius {
	static let sm: CGFloat = 6
	static let md: CGFloat = 10
	static let lg: CGFloat = 14
	static let xl: CGFloat = 22
}

enum Motion {
	static let standard = Animation.smooth(duration: 0.25)

	/// Critically damped: the player settles without bouncing and keeps the speed of the finger.
	static func player(velocity: CGFloat = 0) -> Animation {
		.interpolatingSpring(duration: 0.38, bounce: 0, initialVelocity: velocity)
	}
}
