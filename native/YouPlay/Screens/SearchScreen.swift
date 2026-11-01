import SwiftUI

struct SearchScreen: View {
	@Environment(PlayerModel.self) private var player
	@Environment(AppRouter.self) private var router
	@State private var query = ""
	@State private var channels: [Channel] = []
	@State private var isSearching = false
	@State private var errorMessage: String?
	@State private var searchedQuery = ""

	private static let debounce = Duration.milliseconds(400)

	var body: some View {
		@Bindable var router = router

		NavigationStack(path: $router.searchPath) {
			List(channels) { channel in
				NavigationLink(value: ChannelRoute(id: channel.id, name: channel.name)) {
					ChannelRow(channel: channel)
				}
				.contentRow()
			}
			.contentList()
			.miniPlayerInset(player)
			.overlay { emptyState }
			.navigationTitle("Cerca")
			.channelNavigation()
			.searchable(text: $query, prompt: "Canali")
			// Keeps the screen's title on screen while searching.
			.searchPresentationToolbarBehavior(.avoidHidingContent)
			.task(id: query) { await search() }
		}
	}

	@ViewBuilder
	private var emptyState: some View {
		if channels.isEmpty {
			if isSearching {
				ProgressView()
			} else if let errorMessage {
				ContentUnavailableView("Ricerca non riuscita", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
			} else if searchedQuery.isEmpty {
				ContentUnavailableView(
					"Cerca un canale",
					systemImage: "magnifyingglass",
					description: Text("Seguilo per ritrovare i suoi video nella Home.")
				)
			} else {
				ContentUnavailableView.search(text: searchedQuery)
			}
		}
	}

	private func search() async {
		let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty else {
			channels = []
			searchedQuery = ""
			errorMessage = nil
			return
		}
		try? await Task.sleep(for: Self.debounce)
		guard !Task.isCancelled else { return }

		isSearching = true
		defer { isSearching = false }
		do {
			let results = try await InnerTubeClient.shared.searchChannels(text)
			guard !Task.isCancelled else { return }
			channels = results
			searchedQuery = text
			errorMessage = nil
		} catch {
			guard !Task.isCancelled else { return }
			channels = []
			errorMessage = error.localizedDescription
		}
	}
}
