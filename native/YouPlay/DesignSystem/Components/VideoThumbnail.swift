import SwiftUI

struct VideoThumbnail: View {
	let url: URL?
	var fallbackURL: URL?
	var badge: String?

	var body: some View {
		RemoteImage(url: url, fallbackURL: fallbackURL)
			.aspectRatio(16 / 9, contentMode: .fit)
			.clipShape(.rect(cornerRadius: Radius.lg, style: .continuous))
			.overlay(alignment: .bottomTrailing) {
				if let badge {
					Text(badge)
						.font(Typography.badge)
						.foregroundStyle(Palette.badgeText)
						.padding(.horizontal, Spacing.sm)
						.padding(.vertical, Spacing.xs)
						.background(Palette.badgeBackground, in: .rect(cornerRadius: Radius.sm, style: .continuous))
						.padding(Spacing.sm)
				}
			}
	}
}
