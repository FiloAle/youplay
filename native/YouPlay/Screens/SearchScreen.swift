import SwiftUI

struct SearchScreen: View {
	@Environment(PlayerModel.self) private var player
	@Environment(AppRouter.self) private var router
	@State private var query = ""
	@State private var search = SearchModel()

	var body: some View {
		@Bindable var router = router

		NavigationStack(path: $router.searchPath) {
			List {
				if let channel = search.results.topChannel {
					channelRow(channel)
					if !search.results.latestVideos.isEmpty {
						SectionTitle(title: "Ultimi video")
						ForEach(search.results.latestVideos) { VideoRow(video: $0, showsChannel: false) }
					}
					if !search.results.others.isEmpty {
						SectionTitle(title: "Altri risultati")
					}
				}

				ForEach(search.results.others) { item in
					Group {
						switch item {
						case .channel(let channel): channelRow(channel)
						case .video(let video): VideoRow(video: video)
						}
					}
					.onAppear { if item.id == search.results.others.last?.id { search.loadMore() } }
				}

				if search.isLoadingMore {
					ProgressView()
						.frame(maxWidth: .infinity)
						.contentRow(top: Spacing.lg, bottom: Spacing.lg)
				}
			}
			// New results start from the top.
			.id(search.searchedQuery)
			.contentList()
			.miniPlayerInset(player)
			.overlay { emptyState }
			.screenTitle("Cerca")
			.channelNavigation()
			.searchable(text: $query, prompt: "Canali e video")
			// Keeps the screen's title on screen while searching.
			.searchPresentationToolbarBehavior(.avoidHidingContent)
			.task(id: query) { await search.search(query) }
		}
	}

	private func channelRow(_ channel: Channel) -> some View {
		NavigationLink(value: ChannelRoute(id: channel.id, name: channel.name)) {
			ChannelRow(channel: channel)
		}
		.contentRow()
	}

	@ViewBuilder
	private var emptyState: some View {
		if search.results.isEmpty {
			if search.isSearching {
				ProgressView()
			} else if let errorMessage = search.errorMessage {
				ContentUnavailableView("Ricerca non riuscita", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
			} else if search.searchedQuery.isEmpty {
				ContentUnavailableView(
					"Cerca canali e video",
					systemImage: "magnifyingglass",
					description: Text("Trova un video da guardare o un canale da seguire.")
				)
			} else {
				ContentUnavailableView.search(text: search.searchedQuery)
			}
		}
	}
}

@MainActor
@Observable
final class SearchModel {
	private(set) var results = SearchResults()
	private(set) var searchedQuery = ""
	private(set) var isSearching = false
	private(set) var isLoadingMore = false
	private(set) var errorMessage: String?

	private static let debounce = Duration.milliseconds(500)

	private var loadMoreTask: Task<Void, Never>?

	/// Meant for a `task(id:)`, which cancels it as soon as the text changes.
	func search(_ query: String) async {
		let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty else {
			loadMoreTask?.cancel()
			results = SearchResults()
			searchedQuery = ""
			errorMessage = nil
			return
		}
		try? await Task.sleep(for: Self.debounce)
		guard !Task.isCancelled else { return }

		isSearching = true
		defer { if !Task.isCancelled { isSearching = false } }
		do {
			let found = try await InnerTubeClient.shared.search(text)
			guard !Task.isCancelled else { return }
			loadMoreTask?.cancel()
			isLoadingMore = false
			results = found
			searchedQuery = text
			errorMessage = nil
		} catch {
			guard !Task.isCancelled else { return }
			results = SearchResults()
			errorMessage = error.localizedDescription
		}
	}

	func loadMore() {
		guard !isLoadingMore, let continuation = results.continuation else { return }
		isLoadingMore = true
		loadMoreTask = Task {
			let page = try? await InnerTubeClient.shared.searchPage(continuation: continuation)
			guard !Task.isCancelled else { return }
			if let page { results.append(page) }
			isLoadingMore = false
		}
	}
}
