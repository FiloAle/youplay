import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
	private var mainWindow: UIWindow?

	func application(
		_ application: UIApplication,
		didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
	) -> Bool {
		URLCache.shared = URLCache(memoryCapacity: 20_000_000, diskCapacity: 200_000_000)

		// Not a scene delegate: iOS keeps the scene sessions of the installed version, and an update
		// over one that had another delegate would never call this one, leaving a black screen.
		// The scene may have connected already, which is why both cases are here.
		NotificationCenter.default.addObserver(
			forName: UIScene.willConnectNotification,
			object: nil,
			queue: .main
		) { [weak self] notification in
			let scene = notification.object as? UIScene
			MainActor.assumeIsolated { self?.showWindow(in: scene) }
		}
		showWindow(in: application.connectedScenes.first)
		return true
	}

	private func showWindow(in scene: UIScene?) {
		guard mainWindow == nil, let scene = scene as? UIWindowScene else { return }
		let window = UIWindow(windowScene: scene)
		window.rootViewController = PortraitHostingController(rootView: AppRoot())
		window.makeKeyAndVisible()
		mainWindow = window
	}
}

/// Only the full-screen video rotates, which AVKit does on its own screen. If the app rotated with it,
/// every list would be laid out again in landscape, underneath, while the video goes in and out of full screen.
/// SwiftUI's own `App` has no way to do this, so the app sets up its window itself.
private final class PortraitHostingController: UIHostingController<AppRoot> {
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		.portrait
	}
}

private struct AppRoot: View {
	@State private var player = PlayerModel()
	@State private var subscriptions = SubscriptionStore()
	@State private var router = AppRouter()

	var body: some View {
		RootView()
			.environment(player)
			.environment(subscriptions)
			.environment(router)
			.tint(Palette.accent)
	}
}
