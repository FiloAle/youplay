import SwiftUI

/// Long text in a box, collapsed to a few lines. The toggle only shows when something is cut off.
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

			if fullHeight > collapsedHeight + 1 || isExpanded {
				Button(isExpanded ? "Mostra meno" : "Mostra di più") {
					withAnimation(Motion.standard) { isExpanded.toggle() }
				}
				.font(Typography.rowTitle)
				.foregroundStyle(Palette.textPrimary)
				.buttonStyle(.plain)
			}
		}
		.font(Typography.body)
		.padding(Spacing.md)
		.background(Palette.surface, in: .rect(cornerRadius: Radius.lg, style: .continuous))
		.onChange(of: text) { isExpanded = false }
	}
}
