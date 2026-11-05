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
	/// Dims the video under its controls.
	static let videoScrim = Color.black.opacity(0.35)
	/// The part of the progress bar still to play.
	static let progressTrack = Color.white.opacity(0.35)
	static let shadow = Color.black.opacity(0.3)
}

enum Typography {
	static let screenTitle = Font.largeTitle.bold()
	static let screenTitleDetail = Font.largeTitle
	static let channelName = Font.title2.bold()
	static let title = Font.title3.weight(.semibold)
	static let sectionTitle = Font.headline
	static let cardTitle = Font.callout.weight(.semibold)
	static let rowTitle = Font.subheadline.weight(.semibold)
	static let body = Font.subheadline
	static let metadata = Font.footnote
	static let badge = Font.caption.weight(.semibold).monospacedDigit()
	static let videoControl = Font.footnote.weight(.semibold)
	static let prominentVideoControl = Font.title2.weight(.semibold)
}

enum Spacing {
	static let xxs: CGFloat = 2
	static let xs: CGFloat = 4
	static let sm: CGFloat = 8
	static let md: CGFloat = 12
	static let lg: CGFloat = 16
	static let xl: CGFloat = 24
}

enum Metrics {
	static let moreMenuWidth: CGFloat = 32
	static let compactThumbnailWidth: CGFloat = 112
	static let avatar: CGFloat = 44
	static let smallAvatar: CGFloat = 36
	static let channelAvatar: CGFloat = 80
	static let minimumTouchTarget: CGFloat = 44
	/// Height of the navigation bar and of its buttons.
	static let toolbarHeight: CGFloat = 44
	static let videoControl: CGFloat = 34
	static let prominentVideoControl: CGFloat = 60
	static let progressTrack: CGFloat = 3
	static let progressThumb: CGFloat = 14
	static let disabledOpacity = 0.4
	static let shadowRadius: CGFloat = 12
}

enum Radius {
	static let sm: CGFloat = 6
	static let md: CGFloat = 10
	static let lg: CGFloat = 14
}

enum Motion {
	static let standard = Animation.smooth(duration: 0.25)

	/// Of the player's transitions: expanding, collapsing, full screen.
	static let transitionDuration: TimeInterval = 0.38

	/// Critically damped: the player settles without bouncing and keeps the speed of the finger.
	static func player(velocity: CGFloat = 0) -> Animation {
		.interpolatingSpring(duration: transitionDuration, bounce: 0, initialVelocity: velocity)
	}

	/// How long the video's controls stay on screen while it plays.
	static let controlsTimeout: Duration = .seconds(3)
}
