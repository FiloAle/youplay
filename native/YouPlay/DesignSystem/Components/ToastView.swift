import SwiftUI

struct ToastView: View {
	let message: String

	var body: some View {
		Label(message, systemImage: "checkmark.circle.fill")
			.font(Typography.rowTitle)
			.foregroundStyle(Palette.textPrimary)
			.padding(.horizontal, Spacing.lg)
			.padding(.vertical, Spacing.md)
			.glassEffect(.regular, in: .capsule)
	}
}
