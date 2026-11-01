import SwiftUI

struct ChannelRow: View {
	let channel: Channel

	var body: some View {
		HStack(spacing: Spacing.md) {
			Avatar(url: channel.avatarURL)
			VStack(alignment: .leading, spacing: 2) {
				Text(channel.name)
					.font(Typography.rowTitle)
					.foregroundStyle(Palette.textPrimary)
					.lineLimit(1)
				if let subscribers = channel.subscribers, !subscribers.isEmpty {
					Text(subscribers)
						.font(Typography.metadata)
						.foregroundStyle(Palette.textSecondary)
				}
			}
		}
	}
}
