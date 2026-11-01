import SwiftUI

/// A video in any list, as a full-width card: tap to play, "…" for the other actions, which long press also opens.
struct VideoRow: View {
	let video: Video
	var showsChannel = true

	@Environment(PlayerModel.self) private var player
	@Environment(AppRouter.self) private var router

	var body: some View {
		Button {
			player.open(video)
		} label: {
			VStack(alignment: .leading, spacing: Spacing.sm) {
				VideoThumbnail(video: video)

				HStack(alignment: .top, spacing: Spacing.xs) {
					Text(video.title)
						.font(Typography.cardTitle)
						.foregroundStyle(Palette.textPrimary)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
						.frame(maxWidth: .infinity, alignment: .leading)
					FirstLineMenu(font: Typography.cardTitle) { actions }
				}

				metadata
			}
			.contentShape(.rect)
		}
		.buttonStyle(RowButtonStyle())
		.contextMenu { actions }
		.contentRow(top: Spacing.md, bottom: Spacing.md)
	}

	/// Where the channel is already obvious, its name leaves the space to the views.
	private var metadata: some View {
		HStack(spacing: Spacing.sm) {
			if let source = showsChannel ? video.channelName : video.views {
				Text(source)
			}
			Spacer(minLength: 0)
			if let publishedAt = video.publishedAt {
				Text(Format.relative(publishedAt))
					.fixedSize()
			}
		}
		.font(Typography.metadata)
		.foregroundStyle(Palette.textSecondary)
		.lineLimit(1)
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
}

struct RowButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.opacity(configuration.isPressed ? 0.6 : 1)
	}
}
