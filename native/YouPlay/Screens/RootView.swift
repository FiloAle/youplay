import SwiftUI

struct RootView: View {
	@Environment(PlayerModel.self) private var player
	@Environment(AppRouter.self) private var router
	@State private var tabBarInset: CGFloat = 0

	var body: some View {
		@Bindable var player = player
		@Bindable var router = router

		ZStack(alignment: .bottom) {
			TabView(selection: $router.tab) {
				Tab("Home", systemImage: "house.fill", value: AppTab.home) {
					HomeScreen()
						.onGeometryChange(for: CGFloat.self, of: \.safeAreaInsets.bottom) { tabBarInset = $0 }
				}
				Tab("Seguiti", systemImage: "rectangle.stack.fill", value: AppTab.followed) {
					FollowedScreen()
				}
				Tab(value: AppTab.search, role: .search) {
					SearchScreen()
				}
			}

			PlayerOverlay(tabBarInset: tabBarInset)
				.ignoresSafeArea(.keyboard)

			if let toast = player.toast {
				ToastView(message: toast)
					.padding(.bottom, tabBarInset + PlayerGeometry.miniVideoHeight + Spacing.lg)
					.transition(.opacity.combined(with: .scale(scale: 0.9)))
					.allowsHitTesting(false)
			}
		}
		.animation(Motion.standard, value: player.toast)
		.sensoryFeedback(.success, trigger: player.toast) { _, new in new != nil }
		// AVPlayerViewController would otherwise hide the status bar while it's on screen.
		.statusBarHidden(false)
		.alert("Riproduzione non riuscita", isPresented: $player.hasError) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(player.errorMessage ?? "")
		}
	}
}

extension View {
	/// Keeps the end of a list visible above the mini player.
	func miniPlayerInset(_ player: PlayerModel) -> some View {
		contentMargins(.bottom, player.current == nil ? 0 : PlayerGeometry.miniVideoHeight + Spacing.md, for: .scrollContent)
	}
}
