import AVFoundation

/// Position and length of what's playing, apart from the player model, so that only the views
/// showing time redraw as it passes.
@MainActor
@Observable
final class PlaybackClock {
	private(set) var currentTime: Double = 0
	private(set) var duration: Double = 0
	/// A live stream has no end to seek to.
	private(set) var isLive = false

	@ObservationIgnored private let player: AVPlayer
	@ObservationIgnored private var observer: Any?

	init(player: AVPlayer) {
		self.player = player
		observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] _ in
			MainActor.assumeIsolated { self?.refresh() }
		}
	}

	func refresh() {
		let time = player.currentTime().seconds
		let itemDuration = player.currentItem?.duration ?? .invalid
		let isReady = player.currentItem?.status == .readyToPlay
		let length = itemDuration.seconds.isFinite ? itemDuration.seconds : 0
		if currentTime != time, time.isFinite { currentTime = time }
		if duration != length { duration = length }
		let live = isReady && itemDuration.isIndefinite
		if isLive != live { isLive = live }
	}
}
