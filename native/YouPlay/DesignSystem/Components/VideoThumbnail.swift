import SwiftUI

struct VideoThumbnail: View {
	let url: URL?
	var badge: String?

	var body: some View {
		RemoteImage(url: url)
			.aspectRatio(16 / 9, contentMode: .fit)
			.clipShape(.rect(cornerRadius: Radius.md, style: .continuous))
			.overlay(alignment: .bottomTrailing) {
				if let badge {
					Text(badge)
						.font(Typography.badge)
						.foregroundStyle(Palette.badgeText)
						.padding(.horizontal, Spacing.xs)
						.padding(.vertical, Spacing.xxs)
						.background(Palette.badgeBackground, in: .rect(cornerRadius: Radius.sm, style: .continuous))
						.padding(Spacing.xs)
				}
			}
	}
}
