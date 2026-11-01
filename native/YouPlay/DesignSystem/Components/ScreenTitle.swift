import SwiftUI

extension View {
	/// The large title of a main screen, with an optional detail in gray on the same line.
	/// It replaces the system title's content but not its place, so that nothing below it ever moves.
	func screenTitle(_ title: String, detail: String? = nil) -> some View {
		navigationTitle(title)
			.toolbar {
				ToolbarItem(placement: .largeTitle) {
					HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
						Text(title)
							.font(Typography.screenTitle)
							.foregroundStyle(Palette.textPrimary)
							.fixedSize()
						if let detail {
							Text(detail)
								.font(Typography.screenTitleDetail)
								.foregroundStyle(Palette.textSecondary)
								.lineLimit(1)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
	}
}
