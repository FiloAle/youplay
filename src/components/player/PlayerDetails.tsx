import EpisodeCard from "@/components/EpisodeCard";
import { usePlayerActions } from "@/contexts/PlayerContext";
import { useRelatedVideos } from "@/hooks/use-related-videos";
import { VideoInfo } from "@/lib/youtube";
import { Button, Host } from "@expo/ui/swift-ui";
import { router } from "expo-router";
import { memo, useCallback, useEffect, useRef } from "react";
import { ActivityIndicator, FlatList, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import DescriptionBox from "./DescriptionBox";
import { glassIconButton } from "./glass-icon-button";
import QualityMenu from "./QualityMenu";
import { Rect } from "./QueuePanel";

interface PlayerDetailsProps {
	video: VideoInfo;
	/** Receives the queue button frame in window coordinates, used as the panel's animation origin. */
	onOpenQueue: (origin: Rect) => void;
}

/** Memoized so that loading details for one related video doesn't re-render the whole list. */
const RelatedEpisode = memo(function RelatedEpisode({
	video,
	onOpenChannel,
}: {
	video: VideoInfo;
	onOpenChannel: (channelId?: string) => void;
}) {
	return (
		<EpisodeCard
			video={video}
			subtitle={video.channelName}
			onSubtitlePress={() => onOpenChannel(video.channelId)}
		/>
	);
});

function PlayerDetails({ video, onOpenQueue }: PlayerDetailsProps) {
	const { setExpanded } = usePlayerActions();
	const { videos: related, category } = useRelatedVideos(video);
	const listRef = useRef<FlatList<VideoInfo>>(null);
	const insets = useSafeAreaInsets();
	const queueButtonRef = useRef<View>(null);

	const openQueue = () => {
		queueButtonRef.current?.measureInWindow((x, y, width, height) =>
			onOpenQueue({ x, y, width, height }),
		);
	};

	useEffect(() => {
		listRef.current?.scrollToOffset({ offset: 0, animated: false });
	}, [video.videoId]);

	const openChannel = useCallback(
		(channelId?: string) => {
			if (!channelId) return;
			setExpanded(false);
			router.push(`/home/channel/${channelId}`);
		},
		[setExpanded],
	);

	const renderItem = useCallback(
		({ item }: { item: VideoInfo }) => <RelatedEpisode video={item} onOpenChannel={openChannel} />,
		[openChannel],
	);

	const meta = [video.channelName, video.viewCount, video.publishedDate].filter(Boolean).join(" • ");

	const header = (
		<View style={styles.header}>
			<Text style={styles.title}>{video.title}</Text>
			<View style={styles.metaRow}>
				<Text style={styles.meta} numberOfLines={1} onPress={() => openChannel(video.channelId)}>
					{meta}
				</Text>
				<Host matchContents style={styles.actions}>
					<QualityMenu />
				</Host>
				<View ref={queueButtonRef} collapsable={false}>
					<Host matchContents style={styles.actions}>
						<Button
							label="Coda"
							systemImage="list.bullet"
							onPress={openQueue}
							modifiers={glassIconButton}
						/>
					</Host>
				</View>
			</View>

			<DescriptionBox videoId={video.videoId} />

			<Text style={styles.sectionTitle}>
				{category ? `Altro da ${category}` : `Altro da ${video.channelName}`}
			</Text>
			{related.length === 0 && <ActivityIndicator color="#888" style={styles.loader} />}
		</View>
	);

	return (
		<FlatList
			ref={listRef}
			data={related}
			keyExtractor={(item) => item.videoId}
			ListHeaderComponent={header}
			renderItem={renderItem}
			contentContainerStyle={[styles.content, { paddingBottom: insets.bottom + 24 }]}
			indicatorStyle="white"
		/>
	);
}

export default memo(PlayerDetails);

const styles = StyleSheet.create({
	content: {
		paddingHorizontal: 16,
	},
	header: {
		paddingTop: 12,
		gap: 12,
		marginBottom: 16,
	},
	title: {
		color: "white",
		fontSize: 18,
		fontWeight: "700",
		lineHeight: 24,
	},
	metaRow: {
		flexDirection: "row",
		alignItems: "center",
		gap: 12,
	},
	meta: {
		flex: 1,
		color: "#AAA",
		fontSize: 13,
	},
	actions: {
		height: 36,
		overflow: "visible",
	},
	sectionTitle: {
		color: "white",
		fontSize: 17,
		fontWeight: "700",
		marginTop: 8,
	},
	loader: {
		marginTop: 8,
	},
});
