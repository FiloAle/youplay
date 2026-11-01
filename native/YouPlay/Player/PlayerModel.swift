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
	private var keptSubtitles: String?
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
		if current?.id != video.id { load(video) }
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
				player.play()
				isLoading = false
			} catch {
				// Another video was opened meanwhile. A network request reports that as an error of its own.
				if !Task.isCancelled { fail(with: error.localizedDescription) }
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

	/// The original language, or what `previous` was using. No track is marked as the default, so iOS would go for
	/// the dub in the phone's language. Subtitles get selected later, by `selectSubtitles`.
	private func selectTracks(of item: AVPlayerItem, keeping previous: AVPlayerItem? = nil) async {
		if let audio = try? await item.asset.loadMediaSelectionGroup(for: .audible) {
			let kept = await selectedTrackName(in: previous, for: .audible)
			let option = audio.options.first { option in
				if let kept { option.trackName == kept } else { option.trackName?.hasSuffix("original") == true }
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
		let option = group.options.first { keptSubtitles != nil && $0.trackName == keptSubtitles }
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

	private func selectedTrackName(in item: AVPlayerItem?, for characteristic: AVMediaCharacteristic) async -> String? {
		guard let item, let group = try? await item.asset.loadMediaSelectionGroup(for: characteristic) else { return nil }
		return item.currentMediaSelection.selectedMediaOption(in: group)?.trackName
	}

	private func fail(with message: String) {
		errorMessage = message
		// A queue can't outlive what's playing, so it moves on to what's next.
		if queue.isEmpty { reset() } else { load(queue.removeFirst()) }
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
			let status = item.status
			Task { @MainActor in
				switch status {
				case .failed: self?.fail(with: "Il player ha rifiutato lo stream video.")
				case .readyToPlay: await self?.selectSubtitles(of: item)
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
	/// The only thing that tells tracks apart: "American English - original", "Italiano - dubbed-auto".
	var trackName: String? {
		AVMetadataItem.metadataItems(from: commonMetadata, filteredByIdentifier: .commonIdentifierTitle).first?.stringValue
	}
}
