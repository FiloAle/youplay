import { useSubscriptions } from "@/contexts/SubscriptionContext";
import { VideoInfo, youtubeService } from "@/lib/youtube";
import { useEffect, useMemo, useState } from "react";

const MAX_RELATED = 30;

/**
 * Recent videos from every channel in the same category as the video's channel.
 * Falls back to the channel's own recent videos when it has no category.
 */
export function useRelatedVideos(video: VideoInfo | null) {
	const { subscriptions } = useSubscriptions();
	const [videos, setVideos] = useState<VideoInfo[]>([]);

	const videoId = video?.videoId;
	const channelId = video?.channelId;
	const category = subscriptions.find((s) => s.id === channelId)?.category;

	const channelIdsKey = useMemo(() => {
		if (category) {
			return subscriptions
				.filter((s) => s.category === category)
				.map((s) => s.id)
				.join(",");
		}
		return channelId ?? "";
	}, [subscriptions, category, channelId]);

	useEffect(() => {
		setVideos([]);
		if (!channelIdsKey) return;

		let aborted = false;
		(async () => {
			const recent = (await youtubeService.getRecentVideos(channelIdsKey.split(",")))
				.filter((v) => v.videoId !== videoId)
				.slice(0, MAX_RELATED);
			if (aborted) return;
			setVideos(recent);

			for await (const enriched of youtubeService.enrichVideoDetails(recent, () => aborted)) {
				if (aborted) return;
				setVideos(enriched);
			}
		})().catch((e) => console.warn("Failed to load related videos", e));

		return () => {
			aborted = true;
		};
	}, [channelIdsKey, videoId]);

	return { videos, category };
}
