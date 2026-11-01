import SwiftUI

/// A video in any list: tap to play, "…" for the other actions, which long press also opens.
struct VideoRow: View {
	let video: Video
	var showsChannel = true
	/// For a queued video. It replaces long press, which then drags the row to reorder it.
	var onRemoveFromQueue: (() -> Void)?
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

			Menu {
				actions
			} label: {
				MoreMenuLabel()
			}
		}
		.contextMenu(menuItems: { if onRemoveFromQueue == nil { actions } })
		.contentRow()
		.task(id: video.id) { await loadDetailsIfNeeded() }
	}

	private var textColumn: some View {
		VStack(alignment: .leading, spacing: Spacing.xs) {
			Text(video.title)
				.font(Typography.rowTitle)
				.foregroundStyle(Palette.textPrimary)
				.lineLimit(2)
				.multilineTextAlignment(.leading)
			VStack(alignment: .leading, spacing: Spacing.xxs) {
				if showsChannel {
					Text(video.channelName)
				}
				if let publishedAt = video.publishedAt {
					Text(Format.relative(publishedAt))
				}
			}
			.font(Typography.metadata)
			.foregroundStyle(Palette.textSecondary)
			.lineLimit(1)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	@ViewBuilder
	private var actions: some View {
		if let onRemoveFromQueue {
			Button("Rimuovi dalla coda", systemImage: "minus.circle", role: .destructive, action: onRemoveFromQueue)
		} else {
			Button("Aggiungi alla coda", systemImage: "text.line.last.and.arrowtriangle.forward") {
				player.enqueue(video)
			}
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
