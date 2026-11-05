import SwiftUI

/// What plays next. Rows are compact, so that several fit and can be dragged around.
struct QueueSheet: View {
	@Environment(PlayerModel.self) private var player
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				ForEach(player.queue) { video in
					Button {
						player.playFromQueue(video)
						dismiss()
					} label: {
						QueueRow(video: video)
					}
					.buttonStyle(RowButtonStyle())
					.contentRow()
				}
				.onDelete(perform: player.removeFromQueue)
				.onMove(perform: player.moveInQueue)
			}
			.contentList()
			.overlay {
				if player.queue.isEmpty {
					ContentUnavailableView(
						"La coda è vuota",
						systemImage: "list.bullet",
						description: Text("Dal menu di un video, scegli «Aggiungi alla coda».")
					)
				}
			}
			.navigationTitle("Coda")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Chiudi", systemImage: "xmark") { dismiss() }
				}
			}
		}
		.presentationDetents([.medium, .large])
		.presentationBackground(Palette.background)
	}
}

private struct QueueRow: View {
	let video: Video

	var body: some View {
		HStack(spacing: Spacing.md) {
			VideoThumbnail(video: video, isCompact: true)
				.frame(width: Metrics.compactThumbnailWidth)
			VStack(alignment: .leading, spacing: Spacing.xs) {
				Text(video.title)
					.font(Typography.rowTitle)
					.foregroundStyle(Palette.textPrimary)
					.lineLimit(2)
					.multilineTextAlignment(.leading)
				Text(video.channelName)
					.font(Typography.metadata)
					.foregroundStyle(Palette.textSecondary)
					.lineLimit(1)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.contentShape(.rect)
	}
}
