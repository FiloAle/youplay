import SwiftUI

/// Everything below the video in the full-page player.
struct PlayerDetails: View {
	let video: Video

	@Environment(PlayerModel.self) private var player
	@Environment(SubscriptionStore.self) private var subscriptions
	@Environment(AppRouter.self) private var router
	@State private var related: [Video] = []
	@State private var fetchedChannel: Channel?
	@State private var isShowingQueue = false

	private static let maxRelatedVideos = 30

	var body: some View {
		List {
			header
				.contentRow(top: Spacing.lg)

			if !related.isEmpty {
				SectionTitle(title: "Altro da \(relatedCategory ?? channel.name)")
				// Within a single channel, repeating its name on every row adds nothing.
				ForEach(related) { VideoRow(video: $0, showsChannel: relatedCategory != nil) }
			}
		}
		.contentList()
		.contentMargins(.bottom, Spacing.xl, for: .scrollContent)
		.id(video.id)
		.sheet(isPresented: $isShowingQueue) { QueueSheet() }
		.task(id: video.channelID) { await loadChannel() }
		.task(id: RelatedKey(videoID: video.id, channelIDs: relatedChannelIDs)) { await loadRelated() }
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: Spacing.lg) {
			QueueButton { isShowingQueue = true }

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

/// Opens the queue, with how many videos are in it.
private struct QueueButton: View {
	let action: () -> Void

	@Environment(PlayerModel.self) private var player

	var body: some View {
		Button(action: action) {
			HStack(spacing: Spacing.sm) {
				Label("In coda", systemImage: "list.bullet")
					.font(Typography.rowTitle)
					.foregroundStyle(Palette.textPrimary)
				Spacer(minLength: 0)
				Text(player.queue.count, format: .number)
					.font(Typography.body.monospacedDigit())
					.foregroundStyle(Palette.textSecondary)
			}
			.padding(Spacing.md)
			.background(Palette.surface, in: .rect(cornerRadius: Radius.lg, style: .continuous))
			.contentShape(.rect)
		}
		.buttonStyle(RowButtonStyle())
	}
}
