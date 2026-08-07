import EmptyState from "@/components/EmptyState";
import EpisodeCard from "@/components/EpisodeCard";
import { useSubscriptions } from "@/contexts/SubscriptionContext";
import { VideoInfo, sortVideosByDate, youtubeService } from "@/lib/youtube";
import { Button, Host, Menu, Group, List, SwipeActions, BottomSheet, Section, Text as SwiftUI_Text } from "@expo/ui/swift-ui";
import { listStyle, listRowSeparator, listRowBackground, listRowInsets, scrollContentBackground, padding, font, foregroundStyle, labelStyle, tint, frame, glassEffect } from "@expo/ui/swift-ui/modifiers";
import { GlassView } from "expo-glass-effect";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import { SymbolView } from "expo-symbols";
import React, { useCallback, useEffect, useState, useMemo } from "react";
import {
	ActivityIndicator,
	Animated,
	RefreshControl,
	StyleSheet,
	Text,
	View,
} from "react-native";
import { Image as SwiftUI_Image } from "@expo/ui/swift-ui";

export default function HomeScreen() {
	const { subscriptions, categories, removeCategory } = useSubscriptions();
	const [feed, setFeed] = useState<VideoInfo[]>([]);
	const [isLoading, setIsLoading] = useState(true);
	const [isRefreshing, setIsRefreshing] = useState(false);
	const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
	const [showManageModal, setShowManageModal] = useState(false);

	const filteredFeed = useMemo(() => {
		if (!selectedCategory) return feed;
		return feed.filter(video => {
			const channel = subscriptions.find(s => s.id === video.channelId);
			return channel?.category === selectedCategory;
		});
	}, [feed, subscriptions, selectedCategory]);

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
			// Phase 1: Progressive chunked fetch
			let currentFeed: VideoInfo[] = [];
			const CHUNK_SIZE = 3;
			
			for (let i = 0; i < subscriptions.length; i += CHUNK_SIZE) {
				if (generationRef.current !== currentGeneration) return;

				const chunk = subscriptions.slice(i, i + CHUNK_SIZE);
				const chunkPromises = chunk.map((sub) =>
					youtubeService.getHomeFeedForChannel(sub.id),
				);
				const results = await Promise.all(chunkPromises);

				if (generationRef.current !== currentGeneration) return;

				const newFeed = results.flat();
				const mergedFeed = [...currentFeed, ...newFeed];
				const uniqueFeedUnsorted = Array.from(
					new Map(mergedFeed.map((v) => [v.videoId, v])).values(),
				);
				const uniqueFeed = sortVideosByDate(uniqueFeedUnsorted);

				const validChannelIds = new Set(subscriptions.map((s) => s.id));
				currentFeed = uniqueFeed.filter((v) =>
					validChannelIds.has(v.channelId ?? ""),
				);

				setFeed(currentFeed);

				// Instant UI unlock after the first chunk
				if (i === 0) {
					setIsLoading(false);
					setIsRefreshing(false);
				}
			}

			// Phase 2: Background Duration Updates
			for await (const updatedFeed of youtubeService.enrichVideoDetails(
				currentFeed,
				() => generationRef.current !== currentGeneration,
			)) {
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
				pointerEvents="box-none"
			>
				<Text style={styles.headerTitle}>Home</Text>
				<View style={styles.headerActions}>
					<Host>
						<Menu
							label={
								<GlassView
									style={styles.iconButton}
									glassEffectStyle="regular"
									pointerEvents="none"
								>
									<SymbolView name="line.3.horizontal.decrease" size={18} tintColor="#fff" />
								</GlassView>
							}
						>
							<Button
								label="Tutte"
								systemImage={selectedCategory === null ? "checkmark" : undefined}
								onPress={() => setSelectedCategory(null)}
							/>
							<Group>
								{categories.map((c) => (
									<Button
										key={c}
										label={c}
										systemImage={selectedCategory === c ? "checkmark" : undefined}
										onPress={() => setSelectedCategory(c)}
									/>
								))}
							</Group>
							<Button
								label="Gestisci categorie"
								systemImage="ellipsis"
								onPress={() => setShowManageModal(true)}
							/>
						</Menu>
					</Host>
				</View>
			</Animated.View>

			<Host style={StyleSheet.absoluteFill} pointerEvents="none">
				<BottomSheet
					isPresented={showManageModal}
					onIsPresentedChange={setShowManageModal}
					onDismiss={() => setShowManageModal(false)}
					fitToContents
				>
					<List modifiers={[listStyle("insetGrouped")]}>
						<Section 
							header={
								<SwiftUI_Text modifiers={[padding({ top: 12, bottom: 4 }), font({ size: 18, weight: "semibold" })]}>
									Categorie
								</SwiftUI_Text>
							}
						>
							<List.ForEach>
								{categories.map((c) => (
									<SwipeActions key={c}>
										<SwiftUI_Text modifiers={[foregroundStyle("white"), padding({ top: 12, bottom: 12, leading: 4 })]}>
											{c}
										</SwiftUI_Text>
										<SwipeActions.Actions edge="trailing" allowsFullSwipe>
											<Button
												role="destructive"
												onPress={() => {
													removeCategory(c);
													if (selectedCategory === c) {
														setSelectedCategory(null);
													}
												}}
											>
												<SwiftUI_Image systemName="trash" color="white" size={20} />
											</Button>
										</SwipeActions.Actions>
									</SwipeActions>
								))}
							</List.ForEach>
						</Section>
					</List>
				</BottomSheet>
			</Host>

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
					data={filteredFeed}
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
		flexDirection: "row",
		alignItems: "flex-end",
		justifyContent: "space-between",
	},
	headerTitle: {
		color: "white",
		fontSize: 34,
		fontWeight: "bold",
		letterSpacing: 0.4,
	},
	headerActions: {
		flexDirection: "row",
		gap: 10,
		paddingBottom: 4,
	},
	iconButton: {
		width: 34,
		height: 34,
		borderRadius: 17,
		overflow: "hidden",
		justifyContent: "center",
		alignItems: "center",
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
