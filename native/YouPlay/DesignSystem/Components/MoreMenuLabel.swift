import SwiftUI

/// The "…" that opens a menu of secondary actions, the same everywhere in the app.
struct MoreMenuLabel: View {
	var body: some View {
		Image(systemName: "ellipsis")
			.foregroundStyle(Palette.textSecondary)
			// Trailing, so the dots line up with the screen margin and with chevrons.
			.frame(width: Metrics.minimumTouchTarget - Spacing.md, height: Metrics.minimumTouchTarget, alignment: .trailing)
			.contentShape(.rect)
			.accessibilityLabel("Altre azioni")
	}
}
