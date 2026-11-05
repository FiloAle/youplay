import Foundation

enum SearchItem: Identifiable, Hashable, Sendable {
	case channel(Channel)
	case video(Video)

	var id: String {
		switch self {
		case .channel(let channel): "channel-\(channel.id)"
		case .video(let video): "video-\(video.id)"
		}
	}
}

struct SearchPage: Sendable {
	let items: [SearchItem]
	let continuation: String?
}

/// YouTube's results, which are already sorted by relevance, with one exception: when the search is
/// the name of a channel, that channel and its latest videos come first.
struct SearchResults: Sendable {
	private static let latestVideosLimit = 5

	private(set) var topChannel: Channel?
	private(set) var latestVideos: [Video] = []
	private(set) var others: [SearchItem] = []
	private(set) var continuation: String?

	var isEmpty: Bool {
		topChannel == nil && others.isEmpty
	}

	init() {}

	init(query: String, page: SearchPage) {
		topChannel = Self.channelNamed(query, in: page.items)
		continuation = page.continuation

		let channelVideos = page.items.compactMap { item -> Video? in
			guard case .video(let video) = item, video.channelID == topChannel?.id else { return nil }
			return video
		}
		latestVideos = Array(InnerTubeParser.merged(channelVideos).prefix(Self.latestVideosLimit))
		append(page.items)
	}

	mutating func append(_ page: SearchPage) {
		continuation = page.continuation
		append(page.items)
	}

	private mutating func append(_ items: [SearchItem]) {
		var known = Set(others.map(\.id))
		if let topChannel { known.insert(SearchItem.channel(topChannel).id) }
		known.formUnion(latestVideos.map { SearchItem.video($0).id })
		others += items.filter { known.insert($0.id).inserted }
	}

	/// An exact match wherever it is, or the very first result if its name starts with the search,
	/// so that "kurzgesagt" finds "Kurzgesagt – In a Nutshell".
	private static func channelNamed(_ query: String, in items: [SearchItem]) -> Channel? {
		let words = words(in: query)
		guard !words.isEmpty else { return nil }

		let channels = items.compactMap { item -> Channel? in
			if case .channel(let channel) = item { channel } else { nil }
		}
		if let exact = channels.first(where: { Self.words(in: $0.name).joined() == words.joined() }) {
			return exact
		}
		if case .channel(let first) = items.first, Self.words(in: first.name).starts(with: words) {
			return first
		}
		return nil
	}

	private static func words(in text: String) -> [String] {
		text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
			.split { !$0.isLetter && !$0.isNumber }
			.map(String.init)
	}
}
