import Foundation
import Observation

/// Latest videos of the followed channels. Starts from the last feed on disk and fills up channel by channel.
@MainActor
@Observable
final class HomeFeedModel {
	private(set) var videos: [Video] = []
	private(set) var isLoading = false

	private nonisolated static let fileURL = URL.cachesDirectory.appending(path: "home-feed.json")
	private nonisolated static let recentWindow: TimeInterval = 7 * 24 * 3600
	private nonisolated static let maxConcurrentRequests = 6

	private var videosByChannel: [String: [Video]] = [:]
	private var liveIDs: Set<String> = []

	init() {
		guard
			let data = try? Data(contentsOf: Self.fileURL),
			let cached = try? JSONDecoder().decode([String: [Video]].self, from: data)
		else { return }
		videosByChannel = cached
		publish()
	}

	func load(channelIDs: [String]) async {
		isLoading = true
		defer { isLoading = false }

		// A channel that fails keeps the videos it already had.
		videosByChannel = videosByChannel.filter { channelIDs.contains($0.key) }
		publish()

		await withTaskGroup(of: (String, [Video]?).self) { group in
			var pending = channelIDs.makeIterator()

			func addNext() {
				guard let id = pending.next() else { return }
				group.addTask { (id, await Self.recentVideos(channelID: id)) }
			}
			for _ in 0..<Self.maxConcurrentRequests { addNext() }

			while let (id, videos) = await group.next() {
				if let videos {
					videosByChannel[id] = videos
					publish()
				}
				addNext()
			}
		}
		save()
		await updateLiveVideos()
	}

	/// The feeds don't say what's live right now. Only a video with no known duration can be, and after the first
	/// load those are few. Scheduled ones aren't live yet, so they stay where their date puts them.
	private func updateLiveVideos() async {
		let candidates = videosByChannel.values.joined().filter { $0.duration == nil }.map(\.id)
		await withTaskGroup(of: (String, VideoDetails?).self) { group in
			for id in candidates {
				group.addTask { (id, await VideoDetailsCache.shared.details(for: id)) }
			}
			for await (id, details) in group {
				guard let isLive = details?.isLive, isLive != liveIDs.contains(id) else { continue }
				if isLive { liveIDs.insert(id) } else { liveIDs.remove(id) }
				publish()
			}
		}
	}

	private func publish() {
		let merged = InnerTubeParser.merged(videosByChannel.values.flatMap(\.self))
		videos = merged.filter { liveIDs.contains($0.id) } + merged.filter { !liveIDs.contains($0.id) }
	}

	private func save() {
		let data = try? JSONEncoder().encode(videosByChannel)
		Task.detached(priority: .utility) {
			try? data?.write(to: Self.fileURL, options: .atomic)
		}
	}

	private nonisolated static func recentVideos(channelID: String) async -> [Video]? {
		// One retry: the feed endpoint occasionally rejects bursts of requests.
		let videos: [Video]
		if let first = try? await RSSFeedClient.videos(channelID: channelID) {
			videos = first
		} else {
			try? await Task.sleep(for: .milliseconds(500))
			guard let second = try? await RSSFeedClient.videos(channelID: channelID) else { return nil }
			videos = second
		}
		let oldest = Date.now.addingTimeInterval(-recentWindow)
		let recent = videos.filter { ($0.publishedAt ?? .distantPast) >= oldest }
		return await VideoDetailsCache.shared.applyKnownDurations(to: recent)
	}
}
