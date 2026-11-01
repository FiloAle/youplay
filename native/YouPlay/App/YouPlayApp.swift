import SwiftUI

@main
struct YouPlayApp: App {
	@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@State private var player = PlayerModel()
	@State private var subscriptions = SubscriptionStore()
	@State private var router = AppRouter()

	init() {
		URLCache.shared = URLCache(memoryCapacity: 20_000_000, diskCapacity: 200_000_000)
	}

	var body: some Scene {
		WindowGroup {
			RootView()
				.environment(player)
				.environment(subscriptions)
				.environment(router)
				.tint(Palette.accent)
		}
	}
}

final class AppDelegate: NSObject, UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		supportedInterfaceOrientationsFor window: UIWindow?
	) -> UIInterfaceOrientationMask {
		OrientationLock.mask
	}
}

/// The app is portrait only, except for the full-screen video.
@MainActor
enum OrientationLock {
	static var mask = UIInterfaceOrientationMask.portrait

	static func set(_ orientations: UIInterfaceOrientationMask) {
		mask = orientations
		guard let scene = UIApplication.shared.connectedScenes.lazy.compactMap({ $0 as? UIWindowScene }).first else { return }
		scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
		scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
	}
}
