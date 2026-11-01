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
	}

	private func publish() {
		videos = InnerTubeParser.merged(videosByChannel.values.flatMap(\.self))
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
