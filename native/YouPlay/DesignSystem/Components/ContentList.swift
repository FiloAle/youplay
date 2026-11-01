import SwiftUI

extension View {
	/// The list style used by every screen. Row heights and gaps come only from `contentRow`.
	func contentList() -> some View {
		listStyle(.plain)
			.scrollContentBackground(.hidden)
			.background(Palette.background)
			.environment(\.defaultMinListRowHeight, 0)
	}

	/// A row with the screen margins. Adjacent rows end up 16 pt apart.
	func contentRow(top: CGFloat = Spacing.sm, bottom: CGFloat = Spacing.sm) -> some View {
		listRowInsets(EdgeInsets(top: top, leading: Spacing.lg, bottom: bottom, trailing: Spacing.lg))
			.listRowSeparator(.hidden)
			.listRowBackground(Color.clear)
	}
}

/// Opens a group of rows: far from what comes before it, close to what it introduces.
struct SectionTitle: View {
	let title: String

	var body: some View {
		Text(title)
			.font(Typography.sectionTitle)
			.foregroundStyle(Palette.textPrimary)
			.contentRow(top: Spacing.xl, bottom: Spacing.xs)
	}
}
