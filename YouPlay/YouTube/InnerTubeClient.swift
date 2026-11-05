import Foundation

enum InnerTubeError: LocalizedError {
	case http(Int)
	case unplayable(String?)
	/// A premiere or a live that hasn't started: not a failure, just early.
	case notStarted(String?)

	var errorDescription: String? {
		switch self {
		case .http(let code): "YouTube ha risposto con l'errore \(code)."
		case .unplayable(let reason): reason ?? "Questo video non è riproducibile."
		case .notStarted(let reason): reason ?? "Non è ancora iniziato."
		}
	}
}

/// YouTube's InnerTube API. Requests and parsing run off the main thread, so they never block the UI.
actor InnerTubeClient {
	static let shared = InnerTubeClient()

	private struct Client: Sendable {
		let context: [String: String]
		let userAgent: String

		init(_ context: [String: String], userAgent: String) {
			// Without the time zone, scheduled times come back in Pacific time.
			self.context = context.merging([
				"hl": "it",
				"gl": "IT",
				"timeZone": TimeZone.current.identifier,
				"utcOffsetMinutes": String(TimeZone.current.secondsFromGMT() / 60),
			]) { $1 }
			self.userAgent = userAgent
		}
	}

	private static let web = Client(
		["clientName": "WEB", "clientVersion": "2.20260623.01.00"],
		userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
	)

	// Adaptive HLS up to 4K, which AVPlayer plays as is. Requires visitor data.
	private static let visionOS = Client(
		[
			"clientName": "VISIONOS",
			"clientVersion": "1.02",
			"deviceMake": "Apple",
			"deviceModel": "RealityDevice17,1",
			"osName": "visionOS",
			"osVersion": "26.5.23O471",
			"platform": "MOBILE",
		],
		userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
	)

	// Fallback: only a 360p progressive stream.
	private static let android = Client(
		["clientName": "ANDROID", "clientVersion": "20.10.38", "osName": "Android", "osVersion": "11"],
		userAgent: "com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip"
	)

	private static let videosTab = "EgZ2aWRlb3PyBgQKAjoA"
	private static let liveTab = "EgdzdHJlYW1z8gYECgJ6AA=="

	private var visitorTask: Task<String?, Error>?

	nonisolated func search(_ query: String) async throws -> SearchResults {
		let response = try await Self.post("search", client: Self.web, body: ["query": query])
		return SearchResults(query: query, page: InnerTubeParser.searchPage(in: response))
	}

	nonisolated func searchPage(continuation: String) async throws -> SearchPage {
		let response = try await Self.post("search", client: Self.web, body: ["continuation": continuation])
		return InnerTubeParser.searchPage(in: response)
	}

	/// Videos and past live streams, merged. A channel with no live tab just adds nothing.
	nonisolated func channelPage(id: String) async throws -> ChannelPage {
		async let videos = Self.post("browse", client: Self.web, body: ["browseId": id, "params": Self.videosTab])
		async let live = try? Self.post("browse", client: Self.web, body: ["browseId": id, "params": Self.liveTab])

		let videosResponse = try await videos
		let channel = InnerTubeParser.channel(id: id, in: videosResponse)
		let tabs = [videosResponse, await live].compactMap(\.self).map {
			InnerTubeParser.videoPage(in: $0, channel: channel)
		}
		return ChannelPage(
			channel: channel,
			videos: InnerTubeParser.merged(tabs.flatMap(\.videos)),
			continuations: tabs.compactMap(\.continuation)
		)
	}

	/// Only the channel's own data, with a single request.
	nonisolated func channel(id: String) async throws -> Channel {
		let response = try await Self.post("browse", client: Self.web, body: ["browseId": id, "params": Self.videosTab])
		return InnerTubeParser.channel(id: id, in: response)
	}

	nonisolated func videos(continuation: String, channel: Channel) async throws -> VideoPage {
		let response = try await Self.post("browse", client: Self.web, body: ["continuation": continuation])
		return InnerTubeParser.videoPage(in: response, channel: channel)
	}

	func stream(videoID: String) async throws -> VideoStream {
		let visitor = try await visitorData()
		let hls = try await Self.post("player", client: Self.visionOS, visitor: visitor, body: ["videoId": videoID])
		if let stream = InnerTubeParser.stream(in: hls) { return stream }

		let progressive = try await Self.post("player", client: Self.android, visitor: visitor, body: ["videoId": videoID])
		if let stream = InnerTubeParser.stream(in: progressive) { return stream }

		let status = hls["playabilityStatus"]
		let reason = status?["reason"]?.string
		if status?["status"]?.string == "LIVE_STREAM_OFFLINE" { throw InnerTubeError.notStarted(reason) }
		throw InnerTubeError.unplayable(reason)
	}

	func details(videoID: String) async throws -> VideoDetails {
		let visitor = try await visitorData()
		let response = try await Self.post("player", client: Self.visionOS, visitor: visitor, body: ["videoId": videoID])
		return InnerTubeParser.details(in: response)
	}

	private func visitorData() async throws -> String? {
		if let visitorTask { return try await visitorTask.value }
		let task = Task {
			let response = try await Self.post("visitor_id", client: Self.web, body: [:])
			return response["responseContext"]?["visitorData"]?.string
		}
		visitorTask = task
		do {
			return try await task.value
		} catch {
			visitorTask = nil
			throw error
		}
	}

	private static func post(
		_ endpoint: String,
		client: Client,
		visitor: String? = nil,
		body: [String: String]
	) async throws -> JSONValue {
		var context = client.context
		if let visitor { context["visitorData"] = visitor }

		var payload: [String: Any] = ["context": ["client": context]]
		payload.merge(body) { $1 }

		var request = URLRequest(url: URL(string: "https://www.youtube.com/youtubei/v1/\(endpoint)?prettyPrint=false")!)
		request.httpMethod = "POST"
		request.httpBody = try JSONSerialization.data(withJSONObject: payload)
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue(client.userAgent, forHTTPHeaderField: "User-Agent")
		if let visitor { request.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id") }

		let (data, response) = try await URLSession.shared.data(for: request)
		if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
			throw InnerTubeError.http(status)
		}
		return try JSONValue(data: data)
	}
}
