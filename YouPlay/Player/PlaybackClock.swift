import AVFoundation

/// Position and length of what's playing, apart from the player model, so that only the views
/// showing time redraw as it passes.
@MainActor
@Observable
final class PlaybackClock {
	private(set) var currentTime: Double = 0
	private(set) var duration: Double = 0
	/// A live stream has no end, only a window of its last hour or so to move around in.
	private(set) var isLive = false
	/// Watching a live stream as it happens, not some way back in its window.
	private(set) var isAtLiveEdge = false
	/// Too close to live to play faster: there isn't enough ahead, and iOS refuses rates above normal.
	private(set) var isNearLiveEdge = false

	/// Where the player can go: the whole video, or a live stream's window.
	@ObservationIgnored private(set) var seekableRange: ClosedRange<Double>?

	/// What the progress bar and the time show: the whole video, or the part of a live stream that can be
	/// watched again, which is full while watching live.
	var timeline: Timeline? {
		if isLive {
			guard let seekableRange, seekableRange.upperBound > seekableRange.lowerBound else { return nil }
			let length = liveTime(endingAt: seekableRange.upperBound) - seekableRange.lowerBound
			let position = isAtLiveEdge ? length : min(max(0, currentTime - seekableRange.lowerBound), length)
			return Timeline(start: seekableRange.lowerBound, length: length, position: position)
		}
		return duration > 0 ? Timeline(start: 0, length: duration, position: min(currentTime, duration)) : nil
	}
	@ObservationIgnored var onLiveEdgeChange: (() -> Void)?

	/// Measured from where live is now, which stays steady while live: up to about 6 seconds behind,
	/// depending on where a seek landed. Ten seconds back is always at least 10.
	private static let liveEdgeTolerance = 8.0
	/// iOS refused 2× about 4 seconds from the window's end, and accepted it from 4.5.
	private static let nearLiveEdgeTolerance = 9.0

	/// When the window's end last moved: it moves a segment at a time, while live keeps going in between.
	@ObservationIgnored private var edgeAnchor: (end: Double, date: Date)?
	/// Longer than a segment, in case the stream stalls.
	private static let maxEdgeExtrapolation = 10.0

	@ObservationIgnored private let player: AVPlayer
	@ObservationIgnored private var observer: Any?

	init(player: AVPlayer) {
		self.player = player
		observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] _ in
			MainActor.assumeIsolated { self?.refresh() }
		}
	}

	/// Where live is now, moving smoothly between the window's steps, so that the distance from it doesn't jump.
	private func liveTime(endingAt end: Double) -> Double {
		guard let edgeAnchor else { return end }
		let estimate = edgeAnchor.end + min(Date.now.timeIntervalSince(edgeAnchor.date), Self.maxEdgeExtrapolation)
		return max(end, estimate)
	}

	func refresh() {
		let item = player.currentItem
		let time = player.currentTime().seconds
		let itemDuration = item?.duration ?? .invalid
		let length = itemDuration.seconds.isFinite ? itemDuration.seconds : 0
		if currentTime != time, time.isFinite { currentTime = time }
		if duration != length { duration = length }

		let live = item?.status == .readyToPlay && itemDuration.isIndefinite
		if isLive != live { isLive = live }

		seekableRange = item?.seekableTimeRanges.last.flatMap { value in
			let range = value.timeRangeValue
			let start = range.start.seconds, end = range.end.seconds
			return start.isFinite && end.isFinite && end >= start ? start...end : nil
		}
		// Only a real step: the end also wobbles by fractions of a second, which would restart the estimate.
		if let end = seekableRange?.upperBound, abs(end - (edgeAnchor?.end ?? -.infinity)) > 1 {
			edgeAnchor = (end, .now)
		}
		// From the steady estimate: the window's end steps every few seconds, and the distance from it would cross
		// the thresholds back and forth while watching live.
		let behind = seekableRange.map { liveTime(endingAt: $0.upperBound) - time } ?? 0
		let atEdge = live && behind < Self.liveEdgeTolerance
		if isAtLiveEdge != atEdge { isAtLiveEdge = atEdge }
		let nearEdge = live && behind < Self.nearLiveEdgeTolerance
		if isNearLiveEdge != nearEdge {
			isNearLiveEdge = nearEdge
			onLiveEdgeChange?()
		}
	}
}

/// A span of the player's time, with the playhead in it, in seconds from its start.
struct Timeline {
	let start: Double
	let length: Double
	let position: Double

	var fraction: Double {
		position / length
	}

	/// The player's time at a fraction of the span.
	func time(at fraction: Double) -> Double {
		start + fraction * length
	}
}
