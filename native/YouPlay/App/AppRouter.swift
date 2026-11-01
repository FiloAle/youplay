import SwiftUI

enum AppTab: Hashable {
	case home, followed, search
}

struct ChannelRoute: Hashable {
	let id: String
	var name: String?
}

/// Tabs and navigation, so that anything (like the player) can open a channel in the current tab.
@MainActor
@Observable
final class AppRouter {
	var tab = AppTab.home
	var homePath: [ChannelRoute] = []
	var followedPath: [ChannelRoute] = []
	var searchPath: [ChannelRoute] = []

	/// Opens a channel in the current tab, unless it's already the page on screen, and collapses the player.
	func open(_ route: ChannelRoute, collapsing player: PlayerModel) {
		// A full-page player hides the push, which would only compete with the collapse for frames.
		var transaction = Transaction()
		transaction.disablesAnimations = player.isExpanded
		withTransaction(transaction) {
			switch tab {
			case .home: push(route, onto: &homePath)
			case .followed: push(route, onto: &followedPath)
			case .search: push(route, onto: &searchPath)
			}
		}
		player.isExpanded = false
	}

	private func push(_ route: ChannelRoute, onto path: inout [ChannelRoute]) {
		if path.last?.id != route.id { path.append(route) }
	}
}

extension View {
	func channelNavigation() -> some View {
		navigationDestination(for: ChannelRoute.self) { ChannelScreen(route: $0) }
	}
}
