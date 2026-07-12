import EmptyState from "@/components/EmptyState";
import EpisodeCard from "@/components/EpisodeCard";
import { useSubscriptions } from "@/contexts/SubscriptionContext";
import { VideoInfo, parseRelativeDate, youtubeService } from "@/lib/youtube";
import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import React, { useCallback, useEffect, useState } from "react";
import {
	ActivityIndicator,
	Animated,
	RefreshControl,
	StyleSheet,
	Text,
	View,
} from "react-native";

export default function HomeScreen() {
	const { subscriptions } = useSubscriptions();
	const [feed, setFeed] = useState<VideoInfo[]>([]);
	const [isLoading, setIsLoading] = useState(true);
	const [isRefreshing, setIsRefreshing] = useState(false);

	const generationRef = React.useRef(0);

	const scrollY = React.useRef(new Animated.Value(0)).current;

	const titleOpacity = scrollY.interpolate({
		inputRange: [0, 40],
		outputRange: [1, 0],
		extrapolate: "clamp",
	});

	const loadFeed = async (isRefresh = false) => {
		if (subscriptions.length === 0) {
			setFeed([]);
			setIsLoading(false);
			setIsRefreshing(false);
			return;
		}

		generationRef.current += 1;
		const currentGeneration = generationRef.current;

		if (!isRefresh) {
			setIsLoading(true);
			setFeed([]);
		}

		try {
			// Phase 1: Rapid parallel RSS fetch
			const rssPromises = subscriptions.map(sub => youtubeService.getRecentChannelVideosRss(sub.id));
			const results = await Promise.all(rssPromises);
			
			if (generationRef.current !== currentGeneration) return;
			
			const newFeed = results.flat();
			const uniqueFeed = Array.from(new Map(newFeed.map(v => [v.videoId, v])).values());
			uniqueFeed.sort((a, b) => {
				const dateA = parseRelativeDate(a.publishedDate);
				const dateB = parseRelativeDate(b.publishedDate);
				if (dateA === dateB) return 0;
				if (dateA === Infinity) return 1;
				if (dateB === Infinity) return -1;
				return dateA - dateB;
			});
			
			const validChannelIds = new Set(subscriptions.map(s => s.id));
			const finalFeed = uniqueFeed.filter(v => validChannelIds.has(v.channelId ?? ""));
			
			setFeed(finalFeed);
			
			// Instant UI unlock
			setIsLoading(false);
			setIsRefreshing(false);
			
			// Phase 2: Background Duration Updates
			for await (const updatedFeed of youtubeService.enrichVideoDetails(finalFeed, () => generationRef.current !== currentGeneration)) {
				if (generationRef.current !== currentGeneration) break;
				setFeed(updatedFeed);
			}
			
		} catch (e) {
			console.error("Feed load error:", e);
			if (generationRef.current === currentGeneration) {
				setIsLoading(false);
				setIsRefreshing(false);
			}
		}
	};

	useEffect(() => {
		loadFeed(false);
		return () => {
			generationRef.current += 1;
		};
	}, [subscriptions]);

	const onRefresh = useCallback(() => {
		setIsRefreshing(true);
		loadFeed(true);
	}, [subscriptions]);

	const renderVideo = ({ item }: { item: VideoInfo }) => (
		<EpisodeCard
			video={item}
			subtitle={item.channelName}
			onSubtitlePress={() => router.push(`/home/channel/${item.channelId}`)}
		/>
	);

	return (
		<View style={styles.container}>
			<LinearGradient
				colors={["rgba(0,0,0,0.9)", "transparent"]}
				style={styles.headerGradient}
				pointerEvents="none"
			/>

			<Animated.View
				style={[styles.header, { opacity: titleOpacity }]}
				pointerEvents="none"
			>
				<Text style={styles.headerTitle}>Home</Text>
			</Animated.View>

			{subscriptions.length === 0 ? (
				<EmptyState
					icon="house"
					title="La tua home è vuota"
					subtitle="Segui qualche canale per vederne gli ultimi episodi qui"
				/>
			) : isLoading ? (
				<View style={styles.loadingContainer}>
					<ActivityIndicator size="large" color="#fff" />
				</View>
			) : (
				<Animated.FlatList
					data={feed}
					keyExtractor={(item) => item.videoId}
					renderItem={renderVideo}
					contentContainerStyle={[styles.listContent, { paddingTop: 140 }]}
					indicatorStyle="white"
					onScroll={Animated.event(
						[{ nativeEvent: { contentOffset: { y: scrollY } } }],
						{ useNativeDriver: true },
					)}
					scrollEventThrottle={16}
					refreshControl={
						<RefreshControl
							refreshing={isRefreshing}
							onRefresh={onRefresh}
							tintColor="#fff"
							progressViewOffset={120}
						/>
					}
				/>
			)}
		</View>
	);
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		backgroundColor: "#000",
	},
	headerGradient: {
		position: "absolute",
		top: 0,
		left: 0,
		right: 0,
		height: 140,
		zIndex: 10,
	},
	header: {
		position: "absolute",
		top: 0,
		left: 0,
		right: 0,
		zIndex: 11,
		paddingHorizontal: 20,
		paddingTop: 60,
		paddingBottom: 20,
	},
	headerTitle: {
		color: "white",
		fontSize: 34,
		fontWeight: "bold",
		letterSpacing: 0.4,
	},
	loadingContainer: {
		flex: 1,
		justifyContent: "center",
		alignItems: "center",
	},
	emptyContainer: {
		flex: 1,
		justifyContent: "center",
		alignItems: "center",
		paddingHorizontal: 32,
	},
	emptyText: {
		color: "white",
		fontSize: 18,
		fontWeight: "600",
		marginTop: 16,
		textAlign: "center",
	},
	emptySubtext: {
		color: "#888",
		fontSize: 15,
		marginTop: 8,
		textAlign: "center",
		lineHeight: 22,
	},
	listContent: {
		paddingHorizontal: 20,
		paddingBottom: 100, // padding for miniplayer
	},
});
