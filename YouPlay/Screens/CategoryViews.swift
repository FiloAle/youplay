import SwiftUI

/// Picks the category of a followed channel. Goes inside a `Menu` or context menu.
struct CategoryMenu: View {
	let channel: Channel
	@Binding var newCategoryChannelID: String?

	@Environment(SubscriptionStore.self) private var subscriptions

	var body: some View {
		Menu("Categoria", systemImage: "folder") {
			ForEach(subscriptions.categories, id: \.self) { category in
				Button {
					subscriptions.toggleCategory(category, for: channel.id)
				} label: {
					if channel.category == category {
						Label(category, systemImage: "checkmark")
					} else {
						Text(category)
					}
				}
			}
			Divider()
			Button("Nuova categoria…", systemImage: "plus") { newCategoryChannelID = channel.id }
		}
	}
}

struct ManageCategoriesSheet: View {
	@Environment(SubscriptionStore.self) private var subscriptions
	@Environment(\.dismiss) private var dismiss
	@State private var isCreating = false

	var body: some View {
		NavigationStack {
			List {
				ForEach(subscriptions.categories, id: \.self) { Text($0) }
					.onDelete { offsets in
						offsets.map { subscriptions.categories[$0] }.forEach(subscriptions.removeCategory)
					}
			}
			.overlay {
				if subscriptions.categories.isEmpty {
					ContentUnavailableView(
						"Nessuna categoria",
						systemImage: "folder",
						description: Text("Le categorie raggruppano i canali e filtrano la Home.")
					)
				}
			}
			.navigationTitle("Categorie")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Chiudi", systemImage: "xmark") { dismiss() }
				}
				ToolbarItem(placement: .primaryAction) {
					Button("Nuova categoria", systemImage: "plus") { isCreating = true }
				}
			}
			.newCategoryAlert(isPresented: $isCreating)
		}
		.presentationDetents([.medium, .large])
		.presentationBackground(Palette.background)
	}
}

private struct NewCategoryAlert: ViewModifier {
	@Binding var isPresented: Bool
	let channelID: String?

	@Environment(SubscriptionStore.self) private var subscriptions
	@State private var name = ""

	func body(content: Content) -> some View {
		content.alert("Nuova categoria", isPresented: $isPresented) {
			TextField("Nome", text: $name)
			Button("Annulla", role: .cancel) { name = "" }
			Button("Crea") {
				subscriptions.createCategory(name, assigningTo: channelID)
				name = ""
			}
		}
	}
}

extension View {
	func newCategoryAlert(isPresented: Binding<Bool>) -> some View {
		modifier(NewCategoryAlert(isPresented: isPresented, channelID: nil))
	}

	/// Shown while `channelID` is set. The new category gets assigned to that channel.
	func newCategoryAlert(channelID: Binding<String?>) -> some View {
		modifier(NewCategoryAlert(
			isPresented: Binding(
				get: { channelID.wrappedValue != nil },
				set: { if !$0 { channelID.wrappedValue = nil } }
			),
			channelID: channelID.wrappedValue
		))
	}
}
