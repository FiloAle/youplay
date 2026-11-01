import CoreTransferable
import Foundation
import Observation
import UniformTypeIdentifiers

/// Followed channels and categories, kept in a JSON file visible in the Files app.
/// It's the same file the Expo app maintains, so an update over that app keeps everything.
@MainActor
@Observable
final class SubscriptionStore {
	private nonisolated static let fileURL = URL.documentsDirectory.appending(path: "subscriptions-backup.json")
	private nonisolated static let maxConcurrentRequests = 6

	private(set) var channels: [Channel] = []
	private(set) var categories: [String] = []
	private(set) var isImporting = false

	init() {
		guard
			let data = try? Data(contentsOf: Self.fileURL),
			let backup = try? SubscriptionBackup(data: data)
		else { return }

		channels = backup.channels.filter { !$0.name.isEmpty }
		categories = backup.categories
		if channels.count < backup.channels.count {
			Task { try? await merge(data) }
		}
	}

	func isFollowing(_ id: String) -> Bool {
		channels.contains { $0.id == id }
	}

	func channel(id: String) -> Channel? {
		channels.first { $0.id == id }
	}

	func toggleFollow(_ channel: Channel) {
		if isFollowing(channel.id) {
			channels.removeAll { $0.id == channel.id }
		} else {
			channels.append(channel)
		}
		save()
	}

	/// Selecting the current category again removes it.
	func toggleCategory(_ category: String, for id: String) {
		update(id) { $0.category = $0.category == category ? nil : category }
		save()
	}

	func createCategory(_ name: String, assigningTo id: String? = nil) {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		if !categories.contains(trimmed) { categories.append(trimmed) }
		if let id { update(id) { $0.category = trimmed } }
		save()
	}

	func removeCategory(_ name: String) {
		categories.removeAll { $0 == name }
		for channel in channels where channel.category == name {
			update(channel.id) { $0.category = nil }
		}
		save()
	}

	/// Updates names, avatars and subscriber counts. Channels that fail keep their current data.
	func refresh() async {
		let fetched = await Self.fetchChannels(ids: channels.map(\.id))
		for channel in fetched {
			update(channel.id) {
				let category = $0.category
				$0 = channel
				$0.category = category
			}
		}
		save()
	}

	func importBackup(from url: URL) async throws {
		isImporting = true
		defer { isImporting = false }

		let isScoped = url.startAccessingSecurityScopedResource()
		defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
		try await merge(Data(contentsOf: url))
	}

	var backup: SubscriptionExport {
		SubscriptionExport(channels: channels, categories: categories)
	}

	private func update(_ id: String, _ change: (inout Channel) -> Void) {
		guard let index = channels.firstIndex(where: { $0.id == id }) else { return }
		change(&channels[index])
	}

	private func merge(_ data: Data) async throws {
		let backup = try SubscriptionBackup(data: data)
		let known = Set(channels.map(\.id))

		var added = backup.channels.filter { !known.contains($0.id) }
		// Compact backups only have IDs: the rest comes from YouTube.
		let incomplete = added.filter { $0.name.isEmpty }
		if !incomplete.isEmpty {
			let fetched = await Self.fetchChannels(ids: incomplete.map(\.id))
			added = added.compactMap { channel in
				guard channel.name.isEmpty else { return channel }
				guard var complete = fetched.first(where: { $0.id == channel.id }) else { return nil }
				complete.category = channel.category
				return complete
			}
		}

		channels += added
		categories += backup.categories.filter { !categories.contains($0) }
		save()
	}

	private func save() {
		let data = try? JSONEncoder().encode(LocalBackup(channels: channels, categories: categories))
		Task.detached(priority: .utility) {
			try? data?.write(to: Self.fileURL, options: .atomic)
		}
	}

	private nonisolated static func fetchChannels(ids: [String]) async -> [Channel] {
		await withTaskGroup(of: Channel?.self) { group in
			var pending = ids.makeIterator()
			var results: [Channel] = []

			func addNext() {
				guard let id = pending.next() else { return }
				group.addTask { try? await InnerTubeClient.shared.channel(id: id) }
			}
			for _ in 0..<maxConcurrentRequests { addNext() }

			while let channel = await group.next() {
				if let channel { results.append(channel) }
				addNext()
			}
			return results
		}
	}
}

/// Version 2: what's kept on disk, with all channel data.
private struct LocalBackup: Codable {
	var version = 2
	let channels: [Channel]
	let categories: [String]
}

/// Version 3: what gets exported, with only IDs and categories.
private struct CompactBackup: Codable {
	struct Entry: Codable {
		let id: String
		let category: String?
	}

	var version = 3
	let channels: [Entry]
	let categories: [String]
}

/// Every backup format the Expo app has ever written.
private struct SubscriptionBackup {
	let channels: [Channel]
	let categories: [String]

	init(data: Data) throws {
		let decoder = JSONDecoder()
		if let local = try? decoder.decode(LocalBackup.self, from: data), local.version == 2 {
			channels = local.channels
			categories = local.categories
		} else if let compact = try? decoder.decode(CompactBackup.self, from: data), compact.version == 3 {
			channels = compact.channels.map { Channel(id: $0.id, name: "", category: $0.category) }
			categories = compact.categories
		} else {
			channels = try decoder.decode([Channel].self, from: data)
			categories = []
		}
	}
}

struct SubscriptionExport: Transferable {
	let channels: [Channel]
	let categories: [String]

	static var transferRepresentation: some TransferRepresentation {
		DataRepresentation(exportedContentType: .json) { export in
			let compact = CompactBackup(
				channels: export.channels.map { .init(id: $0.id, category: $0.category) },
				categories: export.categories
			)
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			return try encoder.encode(compact)
		}
		.suggestedFileName("youplay-canali.json")
	}
}
