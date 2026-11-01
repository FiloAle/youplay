import SwiftUI

struct QueueSheet: View {
	@Environment(PlayerModel.self) private var player
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			List {
				ForEach(player.queue) { video in
					VideoRow(video: video, showsActions: false) {
						player.playFromQueue(video)
						dismiss()
					}
				}
				.onDelete(perform: player.removeFromQueue)
				.onMove(perform: player.moveInQueue)
				.listRowSeparator(.hidden)
			}
			.listStyle(.plain)
			.overlay {
				if player.queue.isEmpty {
					ContentUnavailableView(
						"La coda è vuota",
						systemImage: "list.bullet",
						description: Text("Dal menu di un video, scegli «Aggiungi alla coda».")
					)
				}
			}
			.navigationTitle("Coda")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Chiudi", systemImage: "xmark") { dismiss() }
				}
			}
		}
		.presentationDetents([.medium, .large])
		.presentationBackground(Palette.background)
	}
}
