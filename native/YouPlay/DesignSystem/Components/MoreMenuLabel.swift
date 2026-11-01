import SwiftUI

/// The "…" that opens a menu of secondary actions, the same everywhere in the app.
struct MoreMenuLabel: View {
	var body: some View {
		Image(systemName: "ellipsis")
			.foregroundStyle(Palette.textSecondary)
			// Trailing, so the dots line up with the screen margin and with chevrons.
			.frame(width: Metrics.moreMenuWidth, height: Metrics.minimumTouchTarget, alignment: .trailing)
			.contentShape(.rect)
			.accessibilityLabel("Altre azioni")
	}
}

/// A "…" menu next to a title: as tall as the title's first line, so it centers on it without pushing the title down.
struct FirstLineMenu<Items: View>: View {
	let font: Font
	@ViewBuilder let items: Items

	var body: some View {
		Text(verbatim: " ")
			.font(font)
			.hidden()
			.frame(width: Metrics.moreMenuWidth)
			.overlay {
				Menu {
					items
				} label: {
					MoreMenuLabel()
				}
			}
	}
}
