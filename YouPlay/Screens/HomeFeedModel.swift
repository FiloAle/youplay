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

	private nonisolated static let minimumReloadInterval: TimeInterval = 60

	private var videosByChannel: [String: [Video]] = [:]
	private var liveIDs: Set<String> = []
	/// Upcoming premieres and lives. The feed dates them when they were created, not when they start.
	private var scheduled: [String: Date] = [:]
	private var loadedAt: Date?

	init() {
		guard
			let data = try? Data(contentsOf: Self.fileURL),
			let cached = try? JSONDecoder().decode([String: [Video]].self, from: data)
		else { return }
		videosByChannel = cached
		publish()
	}

	/// When the app comes back, unless it was just loaded.
	func reloadIfStale(channelIDs: [String]) async {
		guard !isLoading, Date.now.timeIntervalSince(loadedAt ?? .distantPast) > Self.minimumReloadInterval else { return }
		await load(channelIDs: channelIDs)
	}

	func load(channelIDs: [String]) async {
		loadedAt = .now
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
		await updateBroadcasts()
	}

	/// The feeds don't say what's live or still to start. Only a video with no known duration can be,
	/// and after the first load those are few. Live ones go first, upcoming ones where their start puts them.
	private func updateBroadcasts() async {
		let candidates = videosByChannel.values.joined().filter { $0.duration == nil }.map(\.id)
		await withTaskGroup(of: (String, VideoDetails?).self) { group in
			for id in candidates {
				group.addTask { (id, await VideoDetailsCache.shared.details(for: id)) }
			}
			for await (id, details) in group {
				guard let details else { continue }
				let isLive = details.isLive
				guard isLive != liveIDs.contains(id) || details.scheduledAt != scheduled[id] else { continue }
				if isLive { liveIDs.insert(id) } else { liveIDs.remove(id) }
				scheduled[id] = details.scheduledAt
				publish()
			}
		}
	}

	private func publish() {
		let all = videosByChannel.values.flatMap(\.self).map { video in
			var video = video
			if let start = scheduled[video.id] { video.scheduledAt = start }
			return video
		}
		let merged = InnerTubeParser.merged(all)
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
