import AVFoundation
import SwiftUI

@MainActor
@Observable
final class PlayerModel {
	let player = AVPlayer()

	private(set) var current: Video?
	private(set) var description: String?
	private(set) var isLoading = false
	private(set) var isPlaying = false
	private(set) var errorMessage: String?
	private(set) var toast: String?
	private(set) var queue: [Video] = []
	private(set) var maxQuality = UserDefaults.standard.integer(forKey: DefaultsKey.maxQuality)
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
	private var loadTask: Task<Void, Never>?
	private var toastTask: Task<Void, Never>?
	private var playbackObservation: NSKeyValueObservation?
	private var rateObservation: NSKeyValueObservation?
	private var itemObservation: NSKeyValueObservation?
	private var endObserver: NSObjectProtocol?

	init() {
		try? AVAudioSession.sharedInstance().setCategory(.playback)
		player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible

		let savedRate = UserDefaults.standard.float(forKey: DefaultsKey.playbackRate)
		if savedRate > 0 { player.defaultRate = savedRate }

		nowPlaying = NowPlayingController(player: player) { [weak self] in self?.playNext() }
		observePlayer()
	}

	// MARK: Playback

	func open(_ video: Video) {
		isExpanded = true
		if current?.id != video.id { load(video, autoplay: true) }
	}

	func togglePlayback() {
		if isPlaying { player.pause() } else { player.play() }
	}

	func playNext() {
		guard !queue.isEmpty else {
			player.pause()
			player.seek(to: .zero)
			return
		}
		load(queue.removeFirst(), autoplay: true)
	}

	func setMaxQuality(_ height: Int) {
		maxQuality = height
		UserDefaults.standard.set(height, forKey: DefaultsKey.maxQuality)
		guard let streamURL, let current else { return }

		// AVPlayer would keep playing what it has already buffered, so the item gets replaced.
		let time = player.currentTime()
		let wasPlaying = isPlaying
		player.replaceCurrentItem(with: makeItem(streamURL, video: current))
		player.seek(to: time)
		if wasPlaying { player.play() }
	}

	/// Stops everything and removes the player from the screen. The queue goes too, since it's only visible in the player.
	func close() {
		queue = []
		reset()
	}

	// MARK: Queue

	func enqueue(_ video: Video) {
		if current == nil {
			load(video, autoplay: false)
		} else {
			queue.append(video)
		}
		showToast("Aggiunto alla coda")
	}

	func playFromQueue(_ video: Video) {
		queue.removeAll { $0.id == video.id }
		open(video)
	}

	func removeFromQueue(_ video: Video) {
		queue.removeAll { $0.id == video.id }
	}

	func removeFromQueue(at offsets: IndexSet) {
		queue.remove(atOffsets: offsets)
	}

	func moveInQueue(from offsets: IndexSet, to destination: Int) {
		queue.move(fromOffsets: offsets, toOffset: destination)
	}

	// MARK: Private

	private func load(_ video: Video, autoplay: Bool) {
		current = video
		description = nil
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
				player.replaceCurrentItem(with: makeItem(stream.url, video: video))
				if autoplay { player.play() }
				isLoading = false
			} catch is CancellationError {
				return
			} catch {
				fail(with: error.localizedDescription)
			}
		}
	}

	private func makeItem(_ url: URL, video: Video) -> AVPlayerItem {
		let item = AVPlayerItem(url: url)
		item.audioTimePitchAlgorithm = .spectral
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

	private func fail(with message: String) {
		errorMessage = message
		reset()
	}

	private func reset() {
		loadTask?.cancel()
		itemObservation = nil
		player.replaceCurrentItem(with: nil)
		current = nil
		description = nil
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
			let isPlaying = player.timeControlStatus != .paused
			Task { @MainActor in
				self?.isPlaying = isPlaying
				self?.nowPlaying?.update()
			}
		}
		// The speed picked in the native controls is remembered for the next videos.
		rateObservation = player.observe(\.rate) { [weak self] player, _ in
			let rate = player.rate
			guard rate > 0 else { return }
			Task { @MainActor in
				self?.player.defaultRate = rate
				UserDefaults.standard.set(rate, forKey: DefaultsKey.playbackRate)
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

	private func observeStatus(of item: AVPlayerItem) {
		itemObservation = item.observe(\.status) { [weak self] item, _ in
			guard item.status == .failed else { return }
			Task { @MainActor in self?.fail(with: "Il player ha rifiutato lo stream video.") }
		}
	}

	private static func metadata(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
		let item = AVMutableMetadataItem()
		item.identifier = identifier
		item.value = value as NSString
		return item
	}
}
