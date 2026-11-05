import SwiftUI

struct ChannelRow: View {
	let channel: Channel
	var avatarSize = Metrics.avatar

	var body: some View {
		HStack(spacing: Spacing.md) {
			Avatar(url: channel.avatarURL, size: avatarSize)
			VStack(alignment: .leading, spacing: Spacing.xxs) {
				Text(channel.name)
					.font(Typography.rowTitle)
					.foregroundStyle(Palette.textPrimary)
					.lineLimit(1)
				if let subscribers = channel.subscribers, !subscribers.isEmpty {
					Text(subscribers)
						.font(Typography.metadata)
						.foregroundStyle(Palette.textSecondary)
						.lineLimit(1)
				}
			}
		}
	}
}
