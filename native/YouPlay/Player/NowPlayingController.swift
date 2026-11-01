import AVFoundation
import MediaPlayer
import UIKit

/// Lock screen and Control Center: what's playing and the remote commands.
@MainActor
final class NowPlayingController {
	private nonisolated static let skipInterval = 10.0
	private static let refreshInterval = CMTime(seconds: 5, preferredTimescale: 1)

	private let player: AVPlayer
	private var video: Video?
	private var artwork: MPMediaItemArtwork?
	private var artworkTask: Task<Void, Never>?
	private var timeObserver: Any?

	init(player: AVPlayer, onNext: @escaping @MainActor () -> Void) {
		self.player = player
		Self.configureCommands(player: player, onNext: onNext)

		// Covers duration and seeks: between refreshes the system extrapolates from the rate.
		timeObserver = player.addPeriodicTimeObserver(forInterval: Self.refreshInterval, queue: .main) { [weak self] _ in
			MainActor.assumeIsolated { self?.update() }
		}
	}

	func show(_ video: Video) {
		self.video = video
		artwork = nil
		update()

		artworkTask?.cancel()
		guard let url = video.thumbnailURL else { return }
		artworkTask = Task {
			guard let image = await ImageLoader.shared.image(for: url), !Task.isCancelled else { return }
			artwork = Self.makeArtwork(image)
			update()
		}
	}

	func update() {
		guard let video else { return }
		var info: [String: Any] = [
			MPMediaItemPropertyTitle: video.title,
			MPMediaItemPropertyArtist: video.channelName,
			MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
			MPNowPlayingInfoPropertyPlaybackRate: player.rate,
			MPNowPlayingInfoPropertyDefaultPlaybackRate: player.defaultRate,
		]
		if let duration = player.currentItem?.duration.seconds, duration.isFinite {
			info[MPMediaItemPropertyPlaybackDuration] = duration
		}
		if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
		MPNowPlayingInfoCenter.default().nowPlayingInfo = info
	}

	func clear() {
		video = nil
		artworkTask?.cancel()
		MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
	}

	// The handlers below run off the main actor, so they must not inherit its isolation.

	private nonisolated static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
		MPMediaItemArtwork(boundsSize: image.size) { _ in image }
	}

	private nonisolated static func configureCommands(
		player: AVPlayer,
		onNext: @escaping @MainActor () -> Void
	) {
		let center = MPRemoteCommandCenter.shared()
		nonisolated(unsafe) let player = player

		center.playCommand.addTarget { _ in
			Task { @MainActor in player.play() }
			return .success
		}
		center.pauseCommand.addTarget { _ in
			Task { @MainActor in player.pause() }
			return .success
		}
		center.togglePlayPauseCommand.addTarget { _ in
			Task { @MainActor in
				if player.timeControlStatus == .paused { player.play() } else { player.pause() }
			}
			return .success
		}
		center.nextTrackCommand.addTarget { _ in
			Task { @MainActor in onNext() }
			return .success
		}

		center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
		center.skipForwardCommand.addTarget { _ in
			Task { @MainActor in
				player.seek(to: player.currentTime() + CMTime(seconds: skipInterval, preferredTimescale: 1))
			}
			return .success
		}
		center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
		center.skipBackwardCommand.addTarget { _ in
			Task { @MainActor in
				player.seek(to: player.currentTime() - CMTime(seconds: skipInterval, preferredTimescale: 1))
			}
			return .success
		}
		center.changePlaybackPositionCommand.addTarget { event in
			guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
			let position = event.positionTime
			Task { @MainActor in
				player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
			}
			return .success
		}
	}
}
