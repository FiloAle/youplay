import SwiftUI

/// Everything below the video in the full-page player.
struct PlayerDetails: View {
	let video: Video

	@Environment(PlayerModel.self) private var player
	@Environment(SubscriptionStore.self) private var subscriptions
	@Environment(AppRouter.self) private var router
	@State private var related: [Video] = []
	@State private var isShowingQueue = false

	private static let maxRelatedVideos = 30

	var body: some View {
		List {
			Section {
				header
				if !related.isEmpty {
					Text(relatedTitle)
						.font(Typography.sectionTitle)
						.foregroundStyle(Palette.textPrimary)
				}
				ForEach(related) { VideoRow(video: $0) }
			}
			.listRowSeparator(.hidden)
		}
		.listStyle(.plain)
		.scrollContentBackground(.hidden)
		.background(Palette.background)
		.id(video.id)
		.sheet(isPresented: $isShowingQueue) { QueueSheet() }
		.task(id: RelatedKey(videoID: video.id, channelIDs: relatedChannelIDs)) { await loadRelated() }
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: Spacing.md) {
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

			HStack(spacing: Spacing.sm) {
				Button {
					router.open(ChannelRoute(id: video.channelID, name: video.channelName), collapsing: player)
				} label: {
					Text(video.channelName)
						.font(Typography.rowTitle)
						.foregroundStyle(Palette.textPrimary)
						.lineLimit(1)
						.frame(maxWidth: .infinity, alignment: .leading)
						.contentShape(.rect)
				}
				.buttonStyle(RowButtonStyle())

				QualityMenu()
				Button { isShowingQueue = true } label: {
					CircleIcon(systemName: "list.bullet", label: "Coda")
				}
				.buttonStyle(RowButtonStyle())
			}

			if let description = player.description, !description.isEmpty {
				ExpandableText(text: description)
			}
		}
	}

	private var metadata: String? {
		let parts = [video.views, video.publishedAt.map(Format.relative)].compactMap(\.self)
		return parts.isEmpty ? nil : parts.joined(separator: " • ")
	}

	private var relatedCategory: String? {
		subscriptions.channel(id: video.channelID)?.category
	}

	private var relatedTitle: String {
		"Altro da \(relatedCategory ?? video.channelName)"
	}

	private var relatedChannelIDs: [String] {
		guard let relatedCategory else { return [video.channelID] }
		return subscriptions.channels.filter { $0.category == relatedCategory }.map(\.id)
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

private struct QualityMenu: View {
	@Environment(PlayerModel.self) private var player

	private static let options = [
		(height: 0, label: "Automatica"),
		(height: 1080, label: "1080p"),
		(height: 720, label: "720p"),
		(height: 480, label: "480p"),
		(height: 360, label: "360p"),
	]

	var body: some View {
		Menu {
			Picker("Qualità massima", selection: Binding(get: { player.maxQuality }, set: player.setMaxQuality)) {
				ForEach(Self.options, id: \.height) { Text($0.label).tag($0.height) }
			}
			.pickerStyle(.inline)
		} label: {
			CircleIcon(systemName: "slider.horizontal.3", label: "Qualità")
		}
	}
}
