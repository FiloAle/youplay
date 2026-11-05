import Foundation

/// A channel's latest 15 videos. Much lighter than InnerTube and has exact dates, but no durations.
enum RSSFeedClient {
	static func videos(channelID: String) async throws -> [Video] {
		var components = URLComponents(string: "https://www.youtube.com/feeds/videos.xml")!
		components.queryItems = [
			URLQueryItem(name: "channel_id", value: channelID),
			// YouTube's CDN keeps a feed for up to 15 minutes, which hides new videos. A new URL skips it.
			URLQueryItem(name: "_", value: String(Int(Date.now.timeIntervalSince1970))),
		]
		var request = URLRequest(url: components.url!)
		request.cachePolicy = .reloadIgnoringLocalCacheData

		let (data, response) = try await URLSession.shared.data(for: request)
		if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
			throw InnerTubeError.http(status)
		}
		let parser = RSSParser(channelID: channelID)
		return parser.parse(data)
	}

	/// Latest videos of many channels, sorted by date. Channels that fail are skipped.
	static func videos(channelIDs: [String]) async -> [Video] {
		await withTaskGroup(of: [Video].self) { group in
			for id in channelIDs {
				group.addTask { (try? await videos(channelID: id)) ?? [] }
			}
			var all: [Video] = []
			for await videos in group { all += videos }
			return InnerTubeParser.merged(all)
		}
	}
}

private final class RSSParser: NSObject, XMLParserDelegate {
	private let channelID: String
	private var videos: [Video] = []
	private var entry: [String: String]?
	private var channelName = ""
	private var text = ""
	private var isShort = false
	private var thumbnail: URL?
	private var views: Int?

	private let dateFormatter = ISO8601DateFormatter()

	init(channelID: String) {
		self.channelID = channelID
	}

	func parse(_ data: Data) -> [Video] {
		let parser = XMLParser(data: data)
		parser.delegate = self
		parser.parse()
		return videos
	}

	func parser(
		_ parser: XMLParser,
		didStartElement name: String,
		namespaceURI: String?,
		qualifiedName: String?,
		attributes: [String: String]
	) {
		text = ""
		switch name {
		case "entry":
			entry = [:]
			isShort = false
			thumbnail = nil
			views = nil
		case "link" where entry != nil:
			isShort = attributes["href"]?.contains("/shorts/") ?? false
		case "media:thumbnail":
			thumbnail = attributes["url"].flatMap(URL.init(string:))
		case "media:statistics":
			views = attributes["views"].flatMap(Int.init)
		default:
			break
		}
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		text += string
	}

	func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
		switch name {
		case "yt:videoId", "title", "published":
			entry?[name] = text
		case "name":
			if channelName.isEmpty { channelName = text }
		case "entry":
			if !isShort, let entry, let id = entry["yt:videoId"], let title = entry["title"] {
				videos.append(Video(
					id: id,
					title: title,
					channelID: channelID,
					channelName: channelName,
					thumbnailURL: thumbnail,
					views: views.map(Format.views),
					publishedAt: entry["published"].flatMap(dateFormatter.date(from:))
				))
			}
			entry = nil
		default:
			break
		}
	}
}
