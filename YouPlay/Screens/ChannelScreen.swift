import SwiftUI

struct ChannelScreen: View {
	let route: ChannelRoute

	@Environment(PlayerModel.self) private var player
	@Environment(SubscriptionStore.self) private var subscriptions
	@State private var page = ChannelPageModel()
	@State private var newCategoryChannelID: String?
	@State private var isTitleVisible = false

	var body: some View {
		List {
			header
				.contentRow(bottom: Spacing.lg)
			ForEach(page.videos) { video in
				VideoRow(video: video, showsChannel: false)
					.onAppear { if video.id == page.videos.last?.id { page.loadMore() } }
			}
			if page.isLoading && channel != nil {
				ProgressView()
					.frame(maxWidth: .infinity)
					.contentRow(top: Spacing.lg, bottom: Spacing.lg)
			}
		}
		.contentList()
		.miniPlayerInset(player)
		.overlay {
			if let errorMessage = page.errorMessage, page.videos.isEmpty {
				ContentUnavailableView {
					Label("Canale non disponibile", systemImage: "wifi.exclamationmark")
				} description: {
					Text(errorMessage)
				} actions: {
					Button("Riprova") { Task { await page.load(id: route.id) } }
				}
			} else if page.isLoading && channel == nil {
				ProgressView()
			}
		}
		// The header already shows the name: the bar only takes over once it has scrolled away.
		.onScrollGeometryChange(for: Bool.self) { geometry in
			geometry.contentOffset.y + geometry.contentInsets.top > Metrics.channelAvatar
		} action: { _, isScrolledPast in
			withAnimation(Motion.standard) { isTitleVisible = isScrolledPast }
		}
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .principal) {
				Text(channel?.name ?? route.name ?? "")
					.font(Typography.sectionTitle)
					.foregroundStyle(Palette.textPrimary)
					.opacity(isTitleVisible ? 1 : 0)
			}
		}
		.newCategoryAlert(channelID: $newCategoryChannelID)
		.task { await page.load(id: route.id) }
	}

	/// What the subscription knows shows right away, then YouTube's data takes over.
	private var channel: Channel? {
		page.channel ?? subscriptions.channel(id: route.id)
	}

	@ViewBuilder
	private var header: some View {
		if let channel {
			VStack(alignment: .leading, spacing: Spacing.lg) {
				HStack(spacing: Spacing.lg) {
					Avatar(url: channel.avatarURL, size: Metrics.channelAvatar)
					VStack(alignment: .leading, spacing: Spacing.xs) {
						Text(channel.name)
							.font(Typography.channelName)
							.foregroundStyle(Palette.textPrimary)
						if let subscribers = channel.subscribers, !subscribers.isEmpty {
							Text(subscribers)
								.font(Typography.metadata)
								.foregroundStyle(Palette.textSecondary)
						}
					}
				}
				followControl(for: channel)
				if let description = channel.description, !description.isEmpty {
					ExpandableText(text: description)
				}
			}
		}
	}

	@ViewBuilder
	private func followControl(for channel: Channel) -> some View {
		if let followed = subscriptions.channel(id: channel.id) {
			Menu {
				CategoryMenu(channel: followed, newCategoryChannelID: $newCategoryChannelID)
				Button("Smetti di seguire", systemImage: "minus.circle", role: .destructive) {
					subscriptions.toggleFollow(followed)
				}
			} label: {
				HStack(spacing: Spacing.xs) {
					Image(systemName: "checkmark")
					Text(followed.category ?? "Seguito")
				}
				.font(Typography.rowTitle)
				.frame(maxWidth: .infinity)
			}
			.buttonStyle(.bordered)
			.buttonBorderShape(.capsule)
		} else {
			Button { subscriptions.toggleFollow(channel) } label: {
				Text("Segui")
					.font(Typography.rowTitle)
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.buttonBorderShape(.capsule)
		}
	}
}

@MainActor
@Observable
final class ChannelPageModel {
	private(set) var channel: Channel?
	private(set) var videos: [Video] = []
	private(set) var isLoading = false
	private(set) var errorMessage: String?

	private var continuations: [String] = []

	func load(id: String) async {
		guard videos.isEmpty, !isLoading else { return }
		isLoading = true
		errorMessage = nil
		defer { isLoading = false }

		do {
			let page = try await InnerTubeClient.shared.channelPage(id: id)
			channel = page.channel
			videos = page.videos
			continuations = page.continuations
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	func loadMore() {
		guard !isLoading, !continuations.isEmpty, let channel else { return }
		isLoading = true
		let tokens = continuations

		Task {
			defer { isLoading = false }
			let pages = await withTaskGroup(of: VideoPage?.self) { group in
				for token in tokens {
					group.addTask { try? await InnerTubeClient.shared.videos(continuation: token, channel: channel) }
				}
				var pages: [VideoPage] = []
				for await page in group {
					if let page { pages.append(page) }
				}
				return pages
			}
			videos = InnerTubeParser.merged(videos + pages.flatMap(\.videos))
			continuations = pages.compactMap(\.continuation)
		}
	}
}
