import Foundation

/// Turns InnerTube responses into models. Keys are searched at any depth, since their nesting changes often.
enum InnerTubeParser {
	static func channels(in response: JSONValue) -> [Channel] {
		response.all("channelRenderer").compactMap { renderer in
			guard
				let id = renderer["channelId"]?.string,
				let name = renderer["title"]?.text,
				!name.isEmpty
			else { return nil }
			// The subscriber count may be in either field, with the handle in the other.
			let subscribers = [renderer["videoCountText"], renderer["subscriberCountText"]]
				.compactMap { $0?.text }
				.first(where: isSubscriberCount)
			return Channel(
				id: id,
				name: name,
				thumbnail: renderer["thumbnail"]?["thumbnails"]?.largestImageURL?.absoluteString,
				subscribers: subscribers,
				description: renderer["descriptionSnippet"]?.text
			)
		}
	}

	static func channel(id: String, in response: JSONValue) -> Channel {
		let metadata = response.first("channelMetadataRenderer")
		return Channel(
			id: id,
			name: metadata?["title"]?.string ?? "",
			thumbnail: metadata?["avatar"]?["thumbnails"]?.largestImageURL?.absoluteString,
			subscribers: response.all("metadataParts")
				.flatMap(\.array)
				.compactMap { $0["text"]?.text }
				.first(where: isSubscriberCount),
			description: metadata?["description"]?.string
		)
	}

	static func videoPage(in response: JSONValue, channel: Channel) -> VideoPage {
		// The first page holds other continuations too (e.g. the "about" panel), so look inside the grid.
		let items = response.first("richGridRenderer") ?? response.first("appendContinuationItemsAction") ?? response
		return VideoPage(
			videos: items.all("lockupViewModel").compactMap { video(from: $0, channel: channel) },
			continuation: items.all("continuationItemRenderer").last?.first("token")?.string
		)
	}

	static func merged(_ videos: [Video]) -> [Video] {
		var seen = Set<String>()
		return videos
			.filter { seen.insert($0.id).inserted }
			.sorted { ($0.scheduledAt ?? $0.publishedAt ?? .distantPast) > ($1.scheduledAt ?? $1.publishedAt ?? .distantPast) }
	}

	static func stream(in response: JSONValue) -> VideoStream? {
		let streaming = response["streamingData"]
		let manifest = streaming?["hlsManifestUrl"]?.string
		let progressive = streaming?["formats"]?.array.compactMap { $0["url"]?.string }.last
		guard let url = (manifest ?? progressive).flatMap(URL.init(string:)) else { return nil }
		return VideoStream(url: url, description: response["videoDetails"]?["shortDescription"]?.string ?? "")
	}

	static func details(in response: JSONValue) -> VideoDetails {
		let details = response["videoDetails"]
		let seconds = details?["lengthSeconds"]?.string.flatMap(Int.init) ?? 0
		let start = response.first("scheduledStartTime")?.string.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
		let isUpcoming = details?["isUpcoming"]?.bool ?? false
		return VideoDetails(
			duration: seconds > 0 ? Format.duration(seconds: seconds) : nil,
			scheduledAt: isUpcoming ? start : nil,
			isLive: details?["isLive"]?.bool ?? false
		)
	}

	private static func video(from lockup: JSONValue, channel: Channel) -> Video? {
		guard
			lockup["contentType"]?.string == "LOCKUP_CONTENT_TYPE_VIDEO",
			let id = lockup["contentId"]?.string,
			let metadata = lockup["metadata"]?["lockupMetadataViewModel"],
			let title = metadata["title"]?.text
		else { return nil }

		let parts = metadata.all("metadataParts").flatMap(\.array).compactMap { $0["text"]?.text }
		let badges = lockup.all("thumbnailBadgeViewModel").compactMap { $0["text"]?.string }
			+ lockup.all("badgeViewModel").compactMap { $0["badgeText"]?.string }

		if badges.contains(where: isMembersOnly) || parts.contains(where: isMembersOnly) { return nil }

		let scheduledAt = parts.lazy.compactMap(Format.date(fromScheduled:)).first
		let duration = badges.first { $0.contains(":") }
		// Without a duration or a schedule it's live right now, which channel pages leave out.
		guard duration != nil || scheduledAt != nil else { return nil }

		return Video(
			id: id,
			title: title,
			channelID: channel.id,
			channelName: channel.name,
			thumbnailURL: lockup["contentImage"]?["thumbnailViewModel"]?["image"]?["sources"]?.smallestImageURL,
			duration: duration,
			views: parts.first { $0.contains("visualizzazion") },
			publishedAt: parts.lazy.compactMap(Format.date(fromRelative:)).first,
			scheduledAt: scheduledAt
		)
	}

	private static func isSubscriberCount(_ text: String) -> Bool {
		let lowercased = text.lowercased()
		return lowercased.contains("iscritt") || lowercased.contains("subscriber")
	}

	private static func isMembersOnly(_ text: String) -> Bool {
		let lowercased = text.lowercased()
		return ["member", "abbonat", "sponsor"].contains(where: lowercased.contains)
	}
}
