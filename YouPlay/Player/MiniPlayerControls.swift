import SwiftUI

/// Sits on top of the mini player's video. The empty space between the buttons lets taps through to the video.
struct MiniPlayerControls: View {
	@Environment(PlayerModel.self) private var player

	var body: some View {
		VStack(spacing: 0) {
			HStack(spacing: 0) {
				Spacer(minLength: 0)
				VideoControlButton(systemName: "xmark", label: "Chiudi") {
					withAnimation(Motion.standard) { player.close() }
				}
			}
			Spacer(minLength: 0)
			HStack(spacing: 0) {
				playbackControl
				Spacer(minLength: 0)
				VideoControlButton(systemName: "forward.fill", label: "Successivo", action: player.playNext)
					.disabled(player.queue.isEmpty)
			}
		}
	}

	@ViewBuilder
	private var playbackControl: some View {
		if player.isWaiting {
			VideoControlCircle {
				ProgressView()
					.controlSize(.small)
					.tint(Palette.badgeText)
			}
		} else {
			VideoControlButton(
				systemName: player.isPlaying ? "pause.fill" : "play.fill",
				label: player.isPlaying ? "Pausa" : "Riproduci",
				action: player.togglePlayback
			)
		}
	}
}
