import Foundation

/// Durations for videos that come from RSS, fetched once per video and kept on disk.
actor VideoDetailsCache {
	static let shared = VideoDetailsCache()

	private static let maxConcurrentRequests = 4
	private static let fileURL = URL.cachesDirectory.appending(path: "video-details.json")

	private var durations: [String: String]
	private var inFlight: [String: Task<VideoDetails?, Never>] = [:]
	private var activeRequests = 0
	private var waiting: [CheckedContinuation<Void, Never>] = []
	private var saveTask: Task<Void, Never>?

	init() {
		let data = try? Data(contentsOf: Self.fileURL)
		durations = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
	}

	/// Fills in what's already known, with no network requests.
	func applyKnownDurations(to videos: [Video]) -> [Video] {
		videos.map { video in
			var video = video
			if video.duration == nil { video.duration = durations[video.id] }
			return video
		}
	}

	func details(for id: String) async -> VideoDetails? {
		if let duration = durations[id] {
			return VideoDetails(duration: duration, scheduledAt: nil, isLive: false)
		}
		if let task = inFlight[id] { return await task.value }

		let task = Task { await fetch(id) }
		inFlight[id] = task
		let details = await task.value
		inFlight[id] = nil
		return details
	}

	private func fetch(_ id: String) async -> VideoDetails? {
		await acquireSlot()
		defer { releaseSlot() }

		guard let details = try? await InnerTubeClient.shared.details(videoID: id) else { return nil }
		// Live and scheduled labels change over time, so only regular durations are kept.
		if let duration = details.duration, !details.isLive, details.scheduledAt == nil {
			durations[id] = duration
			scheduleSave()
		}
		return details
	}

	private func acquireSlot() async {
		if activeRequests < Self.maxConcurrentRequests {
			activeRequests += 1
		} else {
			await withCheckedContinuation { waiting.append($0) }
		}
	}

	private func releaseSlot() {
		if waiting.isEmpty {
			activeRequests -= 1
		} else {
			waiting.removeFirst().resume()
		}
	}

	private func scheduleSave() {
		saveTask?.cancel()
		saveTask = Task {
			try? await Task.sleep(for: .seconds(2))
			guard !Task.isCancelled else { return }
			try? JSONEncoder().encode(durations).write(to: Self.fileURL, options: .atomic)
		}
	}
}
