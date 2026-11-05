import AVFoundation
import SwiftUI

@MainActor
@Observable
final class PlayerModel {
	let player: AVPlayer
	let stage: VideoStage
	let clock: PlaybackClock

	private(set) var current: Video?
	private(set) var description: String?
	private(set) var isLoading = false
	private(set) var isPlaying = false
	/// Asked to play, but short of data: right after opening a video, after a seek, on a slow network.
	private(set) var isBuffering = false

	/// Nothing to show or control yet: the stream is being fetched, or the player is waiting for data.
	var isWaiting: Bool {
		isLoading || isBuffering
	}
	private(set) var errorMessage: String?
	private(set) var toast: String?
	private(set) var queue: [Video] = []
	private(set) var maxQuality = UserDefaults.standard.integer(forKey: DefaultsKey.maxQuality)
	/// The speed picked in the menu, kept for the next videos too.
	private(set) var playbackRate: Float = 1
	/// Names of the current video's tracks, as `name` gives them.
	private(set) var audioTracks: [String] = []
	private(set) var subtitleTracks: [String] = []
	private(set) var selectedAudio: String?
	private(set) var selectedSubtitles: String?
	var isExpanded = false

	var hasError: Bool {
		get { errorMessage != nil }
		set { if !newValue { errorMessage = nil } }
	}

	private enum DefaultsKey {
		static let maxQuality = "maxQuality"
		static let playbackRate = "playbackRate"
	}

	private var nowPlaying: NowPlayingController?
	private var streamURL: URL?
	private var keptSubtitles: String?
	private var loadTask: Task<Void, Never>?
	private var bufferingTask: Task<Void, Never>?
	private var toastTask: Task<Void, Never>?
	private var playbackObservation: NSKeyValueObservation?
	private var itemObservation: NSKeyValueObservation?
	private var endObserver: NSObjectProtocol?

	init() {
		let player = AVPlayer()
		self.player = player
		stage = VideoStage(player: player)
		clock = PlaybackClock(player: player)

		try? AVAudioSession.sharedInstance().setCategory(.playback)
		player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible

		let savedRate = UserDefaults.standard.float(forKey: DefaultsKey.playbackRate)
		if savedRate > 0 {
			player.defaultRate = savedRate
			playbackRate = savedRate
		}
		clock.onLiveEdgeChange = { [weak self] in self?.applyRate() }

		nowPlaying = NowPlayingController(player: player) { [weak self] in self?.playNext() }
		observePlayer()
	}

	// MARK: Playback

	func open(_ video: Video) {
		if current?.id != video.id, let start = video.scheduledAt, start > .now {
			showToast("Inizia \(Format.startTime(start))")
			return
		}
		isExpanded = true
		if current?.id != video.id { load(video) }
	}

	func togglePlayback() {
		if isPlaying { player.pause() } else { player.play() }
	}

	/// Whether skipping is possible right now: not while loading, nor past either end of the video
	/// or of a live stream's window. Forward in a live stream only goes as far as live.
	func canSkip(by seconds: Double) -> Bool {
		guard current != nil, !isWaiting else { return false }
		let time = player.currentTime().seconds
		if clock.isLive {
			guard let range = clock.seekableRange else { return false }
			return seconds < 0 ? time > range.lowerBound + Self.skipMargin : !clock.isAtLiveEdge
		}
		guard clock.duration > 0 else { return false }
		return seconds < 0 ? time > Self.skipMargin : time < clock.duration - Self.skipMargin
	}

	private static let skipMargin = 0.5

	func skip(by seconds: Double) {
		Task { await seek(to: player.currentTime().seconds + seconds) }
	}

	func seek(to seconds: Double) async {
		let range = clock.seekableRange ?? (clock.duration > 0 ? 0...clock.duration : nil)
		let target = range.map { min(max($0.lowerBound, seconds), $0.upperBound) } ?? max(0, seconds)
		await player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
		clock.refresh()
	}

	/// Back to what's happening now, from further back in a live stream.
	func seekToLiveEdge() {
		guard let end = clock.seekableRange?.upperBound else { return }
		Task {
			// Not before it: the nearest segment start would land several seconds behind live.
			await player.seek(to: CMTime(seconds: end, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .positiveInfinity)
			clock.refresh()
		}
	}

	/// The speed actually used: a live stream has nothing ahead to play faster when watched live.
	var effectiveRate: Float {
		clock.isNearLiveEdge ? min(playbackRate, 1) : playbackRate
	}

	func setRate(_ rate: Float) {
		playbackRate = rate
		UserDefaults.standard.set(rate, forKey: DefaultsKey.playbackRate)
		applyRate()
	}

	private func applyRate() {
		let rate = effectiveRate
		player.defaultRate = rate
		// Not by the player's own rate, which is briefly zero during a seek, when this often runs.
		if isPlaying, player.rate != rate { player.rate = rate }
	}

	func selectAudio(_ name: String) {
		select(name, for: .audible)
	}

	/// `nil` turns them off. The choice also goes to the next videos and to quality changes.
	func selectSubtitles(_ name: String?) {
		keptSubtitles = name
		select(name, for: .legible)
	}

	func playNext() {
		guard !queue.isEmpty else {
			player.pause()
			player.seek(to: .zero)
			return
		}
		load(queue.removeFirst())
	}

	func setMaxQuality(_ height: Int) {
		maxQuality = height
		UserDefaults.standard.set(height, forKey: DefaultsKey.maxQuality)
		guard let streamURL, let current else { return }

		// AVPlayer would keep playing what it has already buffered, so the item gets replaced.
		let previous = player.currentItem
		let time = player.currentTime()
		let wasPlaying = isPlaying
		loadTask?.cancel()
		loadTask = Task {
			let item = makeItem(streamURL, video: current)
			await selectTracks(of: item, keeping: previous)
			guard !Task.isCancelled else { return }
			player.replaceCurrentItem(with: item)
			await player.seek(to: time)
			if wasPlaying { player.play() }
		}
	}

	/// Stops everything and removes the player from the screen. The queue goes too, since it's only visible in the player.
	func close() {
		queue = []
		reset()
	}

	// MARK: Queue

	/// The queue is what comes after the current video, so without one there's nothing to add to.
	func enqueue(_ video: Video) {
		guard let current else { return }
		if current.id == video.id {
			showToast("Già in riproduzione")
		} else if queue.contains(where: { $0.id == video.id }) {
			showToast("Già in coda")
		} else {
			queue.append(video)
			showToast("Aggiunto alla coda")
		}
	}

	func playFromQueue(_ video: Video) {
		queue.removeAll { $0.id == video.id }
		open(video)
	}

	func removeFromQueue(at offsets: IndexSet) {
		queue.remove(atOffsets: offsets)
	}

	func moveInQueue(from offsets: IndexSet, to destination: Int) {
		queue.move(fromOffsets: offsets, toOffset: destination)
	}

	// MARK: Private

	private func load(_ video: Video) {
		current = video
		description = nil
		clearTracks()
		streamURL = nil
		isLoading = true
		player.pause()
		nowPlaying?.show(video)

		loadTask?.cancel()
		loadTask = Task {
			do {
				let stream = try await InnerTubeClient.shared.stream(videoID: video.id)
				try Task.checkCancellation()
				description = stream.description
				streamURL = stream.url
				let item = makeItem(stream.url, video: video)
				await selectTracks(of: item)
				try Task.checkCancellation()
				player.replaceCurrentItem(with: item)
				// Faster than normal, a live stream would start from the beginning of its window, stalled.
				// The picked speed comes back once the item is ready and known not to be live.
				player.defaultRate = min(playbackRate, 1)
				player.play()
				isLoading = false
			} catch InnerTubeError.notStarted(let reason) where !Task.isCancelled {
				skipNotStarted(reason ?? "Non è ancora iniziato")
			} catch {
				// Another video was opened meanwhile. A network request reports that as an error of its own.
				if !Task.isCancelled { fail(with: error.localizedDescription) }
			}
		}
	}

	private func makeItem(_ url: URL, video: Video) -> AVPlayerItem {
		let item = AVPlayerItem(url: url)
		// Made for voices: spectral, meant for music, makes them sound metallic away from normal speed.
		item.audioTimePitchAlgorithm = .timeDomain
		if maxQuality > 0 {
			// Bound on the short side, so vertical videos get capped like horizontal ones.
			item.preferredMaximumResolution = CGSize(width: maxQuality * 16 / 9, height: maxQuality)
		}
		item.externalMetadata = [
			Self.metadata(.commonIdentifierTitle, video.title),
			Self.metadata(.commonIdentifierArtist, video.channelName),
		]
		observeStatus(of: item)
		return item
	}

	/// The original language, or what `previous` was using. No track is marked as the default, so iOS would go for
	/// the dub in the phone's language. Subtitles get selected later, by `selectSubtitles`.
	private func selectTracks(of item: AVPlayerItem, keeping previous: AVPlayerItem? = nil) async {
		if let audio = try? await item.asset.loadMediaSelectionGroup(for: .audible) {
			let kept = await selectedTrackName(in: previous, for: .audible)
			let option = audio.options.first { option in
				if let kept { option.name == kept } else { option.name.hasSuffix("original") }
			}
			if let option { item.select(option, in: audio) }
		}
		keptSubtitles = await selectedTrackName(in: previous, for: .legible)
	}

	/// No subtitles, or the ones `keptSubtitles` names. Right after an item gets ready, iOS turns on the ones in the
	/// phone's language for audio in another one, ignoring the item's selection, the player's criteria and the manifest.
	/// So for a moment its choice gets undone. Too early to be the viewer's, whose choices from the menu stay.
	private func selectSubtitles(of item: AVPlayerItem) async {
		guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible) else { return }
		let option = group.options.first { keptSubtitles != nil && $0.name == keptSubtitles }
		let select = {
			if item.currentMediaSelection.selectedMediaOption(in: group) != option { item.select(option, in: group) }
		}
		select()
		let observer = NotificationCenter.default.addObserver(
			forName: AVPlayerItem.mediaSelectionDidChangeNotification,
			object: item,
			queue: .main
		) { _ in select() }
		try? await Task.sleep(for: .seconds(1))
		NotificationCenter.default.removeObserver(observer)
	}

	private func clearTracks() {
		audioTracks = []
		subtitleTracks = []
		selectedAudio = nil
		selectedSubtitles = nil
	}

	private func loadTracks(of item: AVPlayerItem) async {
		let audio = try? await item.asset.loadMediaSelectionGroup(for: .audible)
		let legible = try? await item.asset.loadMediaSelectionGroup(for: .legible)
		guard item === player.currentItem else { return }
		audioTracks = audio?.options.map(\.name) ?? []
		subtitleTracks = legible?.options.map(\.name) ?? []
		refreshSelectedTracks()
	}

	private func refreshSelectedTracks() {
		guard let item = player.currentItem else { return }
		Task {
			selectedAudio = await selectedTrackName(in: item, for: .audible)
			selectedSubtitles = await selectedTrackName(in: item, for: .legible)
		}
	}

	private func select(_ name: String?, for characteristic: AVMediaCharacteristic) {
		guard let item = player.currentItem else { return }
		Task {
			guard let group = try? await item.asset.loadMediaSelectionGroup(for: characteristic) else { return }
			item.select(name.flatMap { name in group.options.first { $0.name == name } }, in: group)
			refreshSelectedTracks()
		}
	}

	private func selectedTrackName(in item: AVPlayerItem?, for characteristic: AVMediaCharacteristic) async -> String? {
		guard let item, let group = try? await item.asset.loadMediaSelectionGroup(for: characteristic) else { return nil }
		return item.currentMediaSelection.selectedMediaOption(in: group)?.name
	}

	private func fail(with message: String) {
		errorMessage = message
		moveOn()
	}

	/// Not an error: a toast says why, and the queue moves on.
	private func skipNotStarted(_ message: String) {
		showToast(message)
		moveOn()
	}

	private func moveOn() {
		// A queue can't outlive what's playing, so it moves on to what's next.
		if queue.isEmpty { reset() } else { load(queue.removeFirst()) }
	}

	private func reset() {
		stage.exitFullScreen(animated: false)
		loadTask?.cancel()
		itemObservation = nil
		player.replaceCurrentItem(with: nil)
		current = nil
		description = nil
		clearTracks()
		streamURL = nil
		isExpanded = false
		isLoading = false
		nowPlaying?.clear()
	}

	private func showToast(_ message: String) {
		toast = message
		toastTask?.cancel()
		toastTask = Task {
			try? await Task.sleep(for: .seconds(1.5))
			if !Task.isCancelled { toast = nil }
		}
	}

	private func observePlayer() {
		playbackObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
			let status = player.timeControlStatus
			Task { @MainActor in
				self?.isPlaying = status != .paused
				self?.updateBuffering(isWaiting: status == .waitingToPlayAtSpecifiedRate)
				self?.nowPlaying?.update()
				// iOS refuses a new rate for a live stream while it settles after a seek, so it's tried again here.
				if status == .playing { self?.applyRate() }
			}
		}
		endObserver = NotificationCenter.default.addObserver(
			forName: AVPlayerItem.didPlayToEndTimeNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated { self?.playNext() }
		}
	}

	/// Resuming waits for a moment too, with the buffer full, which isn't loading anything.
	/// Only a wait that lasts counts.
	private func updateBuffering(isWaiting: Bool) {
		bufferingTask?.cancel()
		guard isWaiting else {
			isBuffering = false
			return
		}
		bufferingTask = Task {
			try? await Task.sleep(for: .milliseconds(400))
			if !Task.isCancelled { isBuffering = true }
		}
	}

	private func observeStatus(of item: AVPlayerItem) {
		itemObservation = item.observe(\.status) { [weak self] item, _ in
			let status = item.status
			Task { @MainActor in
				switch status {
				case .failed: self?.fail(with: "Il player ha rifiutato lo stream video.")
				case .readyToPlay:
					self?.clock.refresh()
					self?.applyRate()
					await self?.selectSubtitles(of: item)
					await self?.loadTracks(of: item)
				default: break
				}
			}
		}
	}

	private static func metadata(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
		let item = AVMutableMetadataItem()
		item.identifier = identifier
		item.value = value as NSString
		return item
	}
}

private extension AVMediaSelectionOption {
	/// What tells audio tracks apart: "American English - original", "Italiano - dubbed-auto".
	/// Subtitles don't have it, and go by the manifest's name: "English", "Deutsch (Deutschland)".
	var name: String {
		AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierTitle).first?.stringValue
			?? displayName
	}
}
