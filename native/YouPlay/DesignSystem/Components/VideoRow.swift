import SwiftUI

/// A video in any list: tap to play, "…" or long press for the other actions.
struct VideoRow: View {
	let video: Video
	var showsChannel = true
	var showsActions = true
	/// Replaces the default action of opening the video.
	var action: (() -> Void)?

	@Environment(PlayerModel.self) private var player
	@Environment(AppRouter.self) private var router
	@State private var details: VideoDetails?

	var body: some View {
		HStack(spacing: Spacing.xs) {
			Button {
				if let action { action() } else { player.open(video) }
			} label: {
				HStack(alignment: .top, spacing: Spacing.md) {
					VideoThumbnail(url: video.thumbnailURL, badge: badge)
						.frame(width: Metrics.thumbnailWidth)
					textColumn
				}
				.contentShape(.rect)
			}
			.buttonStyle(RowButtonStyle())

			if showsActions {
				Menu {
					actions
				} label: {
					Image(systemName: "ellipsis")
						.foregroundStyle(Palette.textSecondary)
						.frame(width: Metrics.minimumTouchTarget - Spacing.md, height: Metrics.minimumTouchTarget)
						.contentShape(.rect)
				}
				.accessibilityLabel("Altre azioni")
			}
		}
		.contextMenu(menuItems: { if showsActions { actions } })
		.task(id: video.id) { await loadDetailsIfNeeded() }
	}

	private var textColumn: some View {
		VStack(alignment: .leading, spacing: Spacing.xs) {
			Text(video.title)
				.font(Typography.rowTitle)
				.foregroundStyle(Palette.textPrimary)
				.lineLimit(2)
				.multilineTextAlignment(.leading)
			if showsChannel {
				Text(video.channelName)
					.font(Typography.metadata)
					.foregroundStyle(Palette.textSecondary)
					.lineLimit(1)
			}
			if let publishedAt = video.publishedAt {
				Text(Format.relative(publishedAt))
					.font(Typography.metadata)
					.foregroundStyle(Palette.textSecondary)
					.lineLimit(1)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private var actions: some View {
		Button("Aggiungi alla coda", systemImage: "text.line.last.and.arrowtriangle.forward") {
			player.enqueue(video)
		}
		if showsChannel {
			Button("Vai al canale", systemImage: "person.crop.circle") {
				router.open(ChannelRoute(id: video.channelID, name: video.channelName), collapsing: player)
			}
		}
	}

	private var badge: String? {
		if details?.isLive == true { return "DAL VIVO" }
		if let scheduledAt = details?.scheduledAt ?? video.scheduledAt { return Format.upcoming(scheduledAt) }
		return video.duration ?? details?.duration
	}

	/// Waits a moment so that rows scrolled past quickly don't cause any request.
	private func loadDetailsIfNeeded() async {
		guard video.duration == nil, video.scheduledAt == nil else { return }
		try? await Task.sleep(for: .milliseconds(150))
		guard !Task.isCancelled else { return }
		details = await VideoDetailsCache.shared.details(for: video.id)
	}
}

struct RowButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.6 : 1)
	}
}
