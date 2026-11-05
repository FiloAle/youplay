import SwiftUI

struct FollowedScreen: View {
	@Environment(PlayerModel.self) private var player
	@Environment(SubscriptionStore.self) private var subscriptions
	@Environment(AppRouter.self) private var router
	@State private var isImporting = false
	@State private var isManagingCategories = false
	@State private var importError: String?
	@State private var newCategoryChannelID: String?

	private struct ChannelSection: Identifiable {
		let id: String
		let title: String?
		let channels: [Channel]
	}

	var body: some View {
		@Bindable var router = router

		NavigationStack(path: $router.followedPath) {
			List(sections) { section in
				if let title = section.title {
					SectionTitle(title: title)
				}
				ForEach(section.channels) { row(for: $0) }
			}
			.contentList()
			.miniPlayerInset(player)
			.refreshable { await subscriptions.refresh() }
			.overlay {
				if subscriptions.channels.isEmpty {
					ContentUnavailableView(
						"Non segui ancora nessun canale",
						systemImage: "rectangle.stack",
						description: Text("Cerca i tuoi canali preferiti e tocca «Segui» per ritrovarli qui.")
					)
				}
			}
			.screenTitle("Seguiti")
			.toolbar { actionsMenu }
			.channelNavigation()
			.newCategoryAlert(channelID: $newCategoryChannelID)
			.sheet(isPresented: $isManagingCategories) { ManageCategoriesSheet() }
			.fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
				importBackup(result)
			}
			.alert("Importazione non riuscita", isPresented: hasImportError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(importError ?? "")
			}
		}
	}

	private func row(for channel: Channel) -> some View {
		NavigationLink(value: ChannelRoute(id: channel.id, name: channel.name)) {
			ChannelRow(channel: channel)
		}
		.contentRow()
		.swipeActions {
			Button("Smetti di seguire", systemImage: "minus.circle", role: .destructive) {
				subscriptions.toggleFollow(channel)
			}
		}
		.contextMenu {
			CategoryMenu(channel: channel, newCategoryChannelID: $newCategoryChannelID)
			Button("Smetti di seguire", systemImage: "minus.circle", role: .destructive) {
				subscriptions.toggleFollow(channel)
			}
		}
	}

	/// Groups by category. With no categories at all, it's a single list with no headers.
	private var sections: [ChannelSection] {
		let sorted = subscriptions.channels.sorted {
			$0.name.localizedStandardCompare($1.name) == .orderedAscending
		}
		let byCategory = subscriptions.categories.compactMap { category -> ChannelSection? in
			let channels = sorted.filter { $0.category == category }
			return channels.isEmpty ? nil : ChannelSection(id: category, title: category, channels: channels)
		}
		let others = sorted.filter { $0.category == nil }
		guard !others.isEmpty else { return byCategory }
		let title = byCategory.isEmpty ? nil : "Senza categoria"
		return byCategory + [ChannelSection(id: "", title: title, channels: others)]
	}

	private var actionsMenu: some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			if subscriptions.isImporting {
				ProgressView()
			} else {
				Menu("Altro", systemImage: "ellipsis") {
					Button("Gestisci categorie", systemImage: "folder") { isManagingCategories = true }
					Divider()
					Button("Importa", systemImage: "square.and.arrow.down") { isImporting = true }
					ShareLink(item: subscriptions.backup, preview: SharePreview("Canali seguiti")) {
						Label("Esporta", systemImage: "square.and.arrow.up")
					}
					.disabled(subscriptions.channels.isEmpty)
				}
			}
		}
	}

	private var hasImportError: Binding<Bool> {
		Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
	}

	private func importBackup(_ result: Result<URL, Error>) {
		Task {
			do {
				try await subscriptions.importBackup(from: result.get())
			} catch {
				importError = "Il file selezionato non è un backup valido."
			}
		}
	}
}
