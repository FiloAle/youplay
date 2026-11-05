import SwiftUI

/// A video's 16:9 image with its duration or live badge.
struct VideoThumbnail: View {
	let video: Video
	var isCompact = false

	@State private var details: VideoDetails?

	var body: some View {
		RemoteImage(url: video.largeThumbnailURL, fallbackURL: video.thumbnailURL)
			.aspectRatio(16 / 9, contentMode: .fit)
			.clipShape(.rect(cornerRadius: isCompact ? Radius.md : Radius.lg, style: .continuous))
			.overlay(alignment: .bottomTrailing) {
				if let badge {
					VideoBadge(text: badge, isLive: isLive, isCompact: isCompact)
						.padding(isCompact ? Spacing.xs : Spacing.sm)
				}
			}
			.task(id: video.id) { await loadDetailsIfNeeded() }
	}

	private var isLive: Bool {
		details?.isLive == true
	}

	private var badge: String? {
		if isLive { return VideoBadge.liveText }
		if let scheduledAt = details?.scheduledAt ?? video.scheduledAt { return Format.upcoming(scheduledAt) }
		return video.duration ?? details?.duration
	}

	/// Waits a moment so that rows scrolled past quickly don't cause any request.
	private func loadDetailsIfNeeded() async {
		guard video.duration == nil, video.scheduledAt == nil else { return }
		try? await Task.sleep(for: .milliseconds(150))
		guard !Task.isCancelled else { return }
		details = await VideoDetailsCache.shared.details(for: video.id)
	}
}
