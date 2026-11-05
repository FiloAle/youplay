import SwiftUI

extension View {
	/// The list style used by every screen. Row heights and gaps come only from `contentRow`.
	func contentList() -> some View {
		listStyle(.plain)
			.scrollContentBackground(.hidden)
			.background(Palette.background)
			.environment(\.defaultMinListRowHeight, 0)
	}

	/// A row with the screen margins. Adjacent rows end up 16 pt apart. Works in a `List` and in a `ContentStack`.
	func contentRow(top: CGFloat = Spacing.sm, bottom: CGFloat = Spacing.sm) -> some View {
		modifier(ContentRow(insets: EdgeInsets(top: top, leading: Spacing.lg, bottom: bottom, trailing: Spacing.lg)))
	}
}

/// The rows of a `List`, with the same gaps, for a page whose rows change height: a `List` resizes its rows
/// in one jump and slides the old content around, while a stack animates them like any other layout.
/// Not lazy, so it suits a page with a few dozen rows at most.
struct ContentStack<Content: View>: View {
	@ViewBuilder let content: Content

	var body: some View {
		ScrollView {
			// Nested on purpose: the rows of a scroll view's own stack, lazy or not, move ahead of an animation
			// inside one of them, overlapping it. One level down, they move with it.
			VStack(spacing: 0) {
				VStack(alignment: .leading, spacing: 0) {
					content
				}
			}
		}
		.background(Palette.background)
		.environment(\.isInContentStack, true)
	}
}

private struct ContentRow: ViewModifier {
	let insets: EdgeInsets

	@Environment(\.isInContentStack) private var isInContentStack

	func body(content: Content) -> some View {
		if isInContentStack {
			content.padding(insets)
		} else {
			content
				.listRowInsets(insets)
				.listRowSeparator(.hidden)
				.listRowBackground(Color.clear)
		}
	}
}

private extension EnvironmentValues {
	@Entry var isInContentStack = false
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
