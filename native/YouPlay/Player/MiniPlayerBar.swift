import SwiftUI

struct MiniPlayerBar: View {
	let video: Video

	@Environment(PlayerModel.self) private var player

	var body: some View {
		HStack(spacing: 0) {
			VStack(alignment: .leading, spacing: 2) {
				Text(video.title)
					.font(Typography.rowTitle)
					.foregroundStyle(Palette.textPrimary)
				Text(video.channelName)
					.font(Typography.metadata)
					.foregroundStyle(Palette.textSecondary)
			}
			.lineLimit(1)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
			.contentShape(.rect)
			.onTapGesture { player.isExpanded = true }

			if player.isLoading {
				ProgressView()
					.frame(width: Metrics.minimumTouchTarget, height: Metrics.minimumTouchTarget)
			} else {
				IconButton(
					systemName: player.isPlaying ? "pause.fill" : "play.fill",
					label: player.isPlaying ? "Pausa" : "Riproduci",
					action: player.togglePlayback
				)
			}
			if !player.queue.isEmpty {
				IconButton(systemName: "forward.fill", label: "Successivo", action: player.playNext)
			}
		}
		.padding(.leading, PlayerGeometry.miniVideoWidth + Spacing.md)
		.padding(.trailing, Spacing.xs)
		.glassEffect(.regular, in: .rect(cornerRadius: Radius.xl, style: .continuous))
	}
}
