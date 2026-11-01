import SwiftUI

struct HomeScreen: View {
	@Environment(PlayerModel.self) private var player
	@Environment(SubscriptionStore.self) private var subscriptions
	@Environment(AppRouter.self) private var router
	@State private var feed = HomeFeedModel()
	@State private var category: String?
	@State private var isManagingCategories = false

	var body: some View {
		@Bindable var router = router

		NavigationStack(path: $router.homePath) {
			List(videos) { VideoRow(video: $0) }
			.contentList()
			.miniPlayerInset(player)
			.refreshable { await feed.load(channelIDs: subscriptions.channels.map(\.id)) }
			.overlay { emptyState }
			.navigationTitle("Home")
			.navigationSubtitle(category ?? "")
			.toolbar { filterMenu }
			.channelNavigation()
			.sheet(isPresented: $isManagingCategories) { ManageCategoriesSheet() }
		}
		.task(id: subscriptions.channels.map(\.id)) {
			await feed.load(channelIDs: subscriptions.channels.map(\.id))
		}
		.onChange(of: subscriptions.categories) {
			if let category, !subscriptions.categories.contains(category) { self.category = nil }
		}
	}

	private var videos: [Video] {
		let followed = subscriptions.channels.filter { category == nil || $0.category == category }
		let ids = Set(followed.map(\.id))
		return feed.videos.filter { ids.contains($0.channelID) }
	}

	@ViewBuilder
	private var emptyState: some View {
		if subscriptions.channels.isEmpty {
			ContentUnavailableView(
				"La tua home è vuota",
				systemImage: "house",
				description: Text("Segui qualche canale per vederne gli ultimi video qui.")
			)
		} else if videos.isEmpty {
			if feed.isLoading {
				ProgressView()
			} else {
				ContentUnavailableView(
					"Nessun video recente",
					systemImage: "play.rectangle",
					description: Text("Qui trovi i video dell'ultima settimana.")
				)
			}
		}
	}

	private var filterMenu: some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			Menu("Filtra", systemImage: "line.3.horizontal.decrease") {
				Picker("Categoria", selection: $category) {
					Text("Tutte").tag(String?.none)
					ForEach(subscriptions.categories, id: \.self) { Text($0).tag(String?.some($0)) }
				}
				.pickerStyle(.inline)
				Button("Gestisci categorie", systemImage: "folder") { isManagingCategories = true }
			}
		}
	}
}
