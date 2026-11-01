import SwiftUI

/// Everything below the video in the full-page player.
struct PlayerDetails: View {
	let video: Video

	@Environment(PlayerModel.self) private var player
	@Environment(SubscriptionStore.self) private var subscriptions
	@Environment(AppRouter.self) private var router
	@State private var related: [Video] = []
	@State private var fetchedChannel: Channel?

	private static let maxRelatedVideos = 30

	var body: some View {
		List {
			header
				.contentRow(top: Spacing.lg)

			if !player.queue.isEmpty {
				SectionTitle(title: "In coda")
				ForEach(player.queue) { queued in
					VideoRow(video: queued, onRemoveFromQueue: { player.removeFromQueue(queued) }) {
						player.playFromQueue(queued)
					}
				}
				.onDelete(perform: player.removeFromQueue)
				.onMove(perform: player.moveInQueue)
			}

			if !unqueuedRelated.isEmpty {
				SectionTitle(title: "Altro da \(relatedCategory ?? video.channelName)")
				// Within a single channel, repeating its name on every row adds nothing.
				ForEach(unqueuedRelated) { VideoRow(video: $0, showsChannel: relatedCategory != nil) }
			}
		}
		.contentList()
		.contentMargins(.bottom, Spacing.xl, for: .scrollContent)
		.id(video.id)
		.task(id: video.channelID) { await loadChannel() }
		.task(id: RelatedKey(videoID: video.id, channelIDs: relatedChannelIDs)) { await loadRelated() }
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: Spacing.lg) {
			HStack(alignment: .top, spacing: Spacing.xs) {
				VStack(alignment: .leading, spacing: Spacing.xs) {
					Text(video.title)
						.font(Typography.title)
						.foregroundStyle(Palette.textPrimary)
					if let metadata {
						Text(metadata)
							.font(Typography.metadata)
							.foregroundStyle(Palette.textSecondary)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				// As tall as the title's first line, so the menu centers on it without pushing the title down.
				Text(verbatim: " ")
					.font(Typography.title)
					.hidden()
					.frame(width: Metrics.minimumTouchTarget - Spacing.md)
					.overlay { VideoOptionsMenu() }
			}

			description

			Button {
				router.open(ChannelRoute(id: video.channelID, name: video.channelName), collapsing: player)
			} label: {
				HStack(spacing: Spacing.sm) {
					ChannelRow(channel: channel, avatarSize: Metrics.smallAvatar)
						.frame(maxWidth: .infinity, alignment: .leading)
					Image(systemName: "chevron.right")
						.font(Typography.metadata)
						.foregroundStyle(Palette.textSecondary)
				}
				.contentShape(.rect)
			}
			.buttonStyle(RowButtonStyle())
		}
	}

	/// While loading it keeps the box's space, so that the rows below don't jump when the text arrives.
	@ViewBuilder
	private var description: some View {
		if let description = player.description {
			if !description.isEmpty {
				ExpandableText(text: description)
			}
		} else {
			Text(verbatim: "")
				.font(Typography.body)
				.lineLimit(ExpandableText.collapsedLines, reservesSpace: true)
				.frame(maxWidth: .infinity)
				.padding(Spacing.md)
				.background(Palette.surface, in: .rect(cornerRadius: Radius.lg, style: .continuous))
		}
	}

	private var metadata: String? {
		let parts = [video.views, video.publishedAt.map(Format.relative)].compactMap(\.self)
		return parts.isEmpty ? nil : parts.joined(separator: " • ")
	}

	/// What's known right away is shown first, then the data fetched from YouTube takes over.
	private var channel: Channel {
		subscriptions.channel(id: video.channelID)
			?? fetchedChannel.flatMap { $0.id == video.channelID ? $0 : nil }
			?? Channel(id: video.channelID, name: video.channelName)
	}

	private var unqueuedRelated: [Video] {
		let queued = Set(player.queue.map(\.id))
		return related.filter { !queued.contains($0.id) }
	}

	private var relatedCategory: String? {
		subscriptions.channel(id: video.channelID)?.category
	}

	private var relatedChannelIDs: [String] {
		guard let relatedCategory else { return [video.channelID] }
		return subscriptions.channels.filter { $0.category == relatedCategory }.map(\.id)
	}

	private func loadChannel() async {
		if let followed = subscriptions.channel(id: video.channelID), followed.avatarURL != nil { return }
		if let channel = try? await InnerTubeClient.shared.channel(id: video.channelID), !Task.isCancelled {
			fetchedChannel = channel
		}
	}

	private func loadRelated() async {
		related = []
		let videos = await RSSFeedClient.videos(channelIDs: relatedChannelIDs)
		guard !Task.isCancelled else { return }
		let others = videos.filter { $0.id != video.id }.prefix(Self.maxRelatedVideos)
		related = await VideoDetailsCache.shared.applyKnownDurations(to: Array(others))
	}
}

private struct RelatedKey: Hashable {
	let videoID: String
	let channelIDs: [String]
}

/// Playback options, which iOS doesn't allow adding to the player's own menu.
private struct VideoOptionsMenu: View {
	@Environment(PlayerModel.self) private var player

	private static let qualities = [
		(height: 0, label: "Automatica"),
		(height: 1080, label: "1080p"),
		(height: 720, label: "720p"),
		(height: 480, label: "480p"),
		(height: 360, label: "360p"),
	]

	var body: some View {
		Menu {
			Picker("Qualità", selection: Binding(get: { player.maxQuality }, set: player.setMaxQuality)) {
				ForEach(Self.qualities, id: \.height) { Text($0.label).tag($0.height) }
			}
			.pickerStyle(.inline)
		} label: {
			MoreMenuLabel()
		}
	}
}
