import Foundation

struct Video: Identifiable, Hashable, Codable, Sendable {
	let id: String
	let title: String
	let channelID: String
	let channelName: String
	let thumbnailURL: URL?
	var duration: String?
	var views: String?
	var publishedAt: Date?
	var scheduledAt: Date?
}

/// Field names match the backup format of the Expo app, so existing data keeps working.
struct Channel: Identifiable, Hashable, Codable, Sendable {
	let id: String
	var name: String
	var thumbnail: String?
	var subscribers: String?
	var description: String?
	var category: String?

	var avatarURL: URL? {
		thumbnail.flatMap(URL.init(string:))
	}
}

struct ChannelPage: Sendable {
	let channel: Channel
	let videos: [Video]
	let continuations: [String]
}

struct VideoPage: Sendable {
	let videos: [Video]
	let continuation: String?
}

struct VideoStream: Sendable {
	let url: URL
	let description: String
}

/// What the RSS feed doesn't say about a video.
struct VideoDetails: Codable, Sendable {
	let duration: String?
	let scheduledAt: Date?
	let isLive: Bool
}
