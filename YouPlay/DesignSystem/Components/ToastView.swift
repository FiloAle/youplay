import SwiftUI

struct ToastView: View {
	let message: String

	var body: some View {
		Label(message, systemImage: "checkmark.circle.fill")
			.font(Typography.rowTitle)
			.foregroundStyle(Palette.textPrimary)
			.padding(.horizontal, Spacing.lg)
			.frame(minHeight: Metrics.toolbarHeight)
			.glassEffect(.regular, in: .capsule)
	}
}
