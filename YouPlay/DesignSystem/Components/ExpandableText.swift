import SwiftUI

/// Long text in a box, collapsed to a few lines. When something is cut off, tapping anywhere on the box
/// expands or collapses it.
///
/// The text is always laid out in full and only its visible height changes, so that it animates as one
/// piece: changing its line limit would swap it for another text midway, which blinks.
struct ExpandableText: View {
	let text: String

	static let collapsedLines = 3

	@State private var isExpanded = false
	@State private var fullHeight: CGFloat = 0
	@State private var collapsedHeight: CGFloat = 0

	var body: some View {
		VStack(alignment: .leading, spacing: Spacing.sm) {
			Text(text)
				// Until it's measured, so that it never shows in full for a moment.
				.lineLimit(collapsedHeight == 0 ? Self.collapsedLines : nil)
				.foregroundStyle(Palette.textSecondary)
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity, alignment: .leading)
				.onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
					if collapsedHeight > 0 { fullHeight = height }
				}
				.frame(height: visibleHeight, alignment: .top)
				.clipped()
				.mask { fade }
				.background(alignment: .topLeading) {
					Text(text)
						.lineLimit(Self.collapsedLines)
						.fixedSize(horizontal: false, vertical: true)
						.hidden()
						.onGeometryChange(for: CGFloat.self, of: \.size.height) { collapsedHeight = $0 }
				}

			if isExpandable {
				// Both always there, so that the label moves with the box: swapping its text would put the new one
				// straight where it ends up, on top of the text still collapsing.
				ZStack(alignment: .leading) {
					Text("Mostra di più").opacity(isExpanded ? 0 : 1)
					Text("Mostra meno").opacity(isExpanded ? 1 : 0)
				}
				.font(Typography.rowTitle)
				.foregroundStyle(Palette.textPrimary)
				.accessibilityHidden(true)
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
		fullHeight > collapsedHeight + 1
	}

	private var visibleHeight: CGFloat? {
		guard isExpandable else { return nil }
		return isExpanded ? fullHeight : collapsedHeight
	}

	/// Fades out the last visible line while collapsed, where a cut-off text would show "…".
	private var fade: some View {
		VStack(spacing: 0) {
			Rectangle()
			LinearGradient(
				colors: [.black, .black.opacity(isExpandable && !isExpanded ? 0 : 1)],
				startPoint: .top,
				endPoint: .bottom
			)
			.frame(height: collapsedHeight / CGFloat(Self.collapsedLines))
		}
	}
}
