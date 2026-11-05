import SwiftUI

/// Long text in a box, collapsed to a few lines. When something is cut off, tapping anywhere on the box
/// expands or collapses it.
struct ExpandableText: View {
	let text: String

	static let collapsedLines = 3

	@State private var isExpanded = false
	@State private var fullHeight: CGFloat = 0
	@State private var collapsedHeight: CGFloat = 0

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.sm) {
			Text(text)
				.lineLimit(isExpanded ? nil : Self.collapsedLines)
				.foregroundStyle(Palette.textSecondary)
				.frame(maxWidth: .infinity, alignment: .leading)
				.onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
					if !isExpanded { collapsedHeight = height }
				}
				.background(alignment: .topLeading) {
					Text(text)
						.fixedSize(horizontal: false, vertical: true)
						.hidden()
						.onGeometryChange(for: CGFloat.self, of: \.size.height) { fullHeight = $0 }
				}

			if isExpandable {
				Text(isExpanded ? "Mostra meno" : "Mostra di più")
					.font(Typography.rowTitle)
					.foregroundStyle(Palette.textPrimary)
			}
		}
		.font(Typography.body)
		.padding(Spacing.md)
		.background(Palette.surface, in: .rect(cornerRadius: Radius.lg, style: .continuous))
		.contentShape(.rect)
		.onTapGesture {
			guard isExpandable else { return }
			withAnimation(Motion.standard) { isExpanded.toggle() }
		}
		.accessibilityAddTraits(isExpandable ? .isButton : [])
		.accessibilityHint(isExpandable ? (isExpanded ? "Mostra meno" : "Mostra di più") : "")
		.onChange(of: text) { isExpanded = false }
	}

	private var isExpandable: Bool {
		fullHeight > collapsedHeight + 1 || isExpanded
	}
}
