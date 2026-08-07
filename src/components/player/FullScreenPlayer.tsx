import { ThemedText } from "@/components/themed-text";
import { Colors, PLAYER_SHEET_FRACTION } from "@/constants/theme";
import { usePlayer } from "@/contexts/PlayerContext";
import { useEvent } from "expo";
import { VideoView } from "expo-video";
import {
	Button,
	Host,
	List,
	SwipeActions,
	Image as SwiftUI_Image,
} from "@expo/ui/swift-ui";
import {
	font,
	tint,
	glassEffect,
	frame,
	labelStyle,
	listStyle,
	scrollContentBackground,
	listRowSeparator,
	listRowBackground,
	listRowInsets,
	listRowSpacing,
} from "@expo/ui/swift-ui/modifiers";
import { useEffect, useState, useRef } from "react";
import {
	Dimensions,
	Image,
	StyleSheet,
	View,
	useColorScheme,
	ActivityIndicator,
} from "react-native";
import { Pressable } from "react-native-gesture-handler";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, {
	useAnimatedStyle,
	withTiming,
} from "react-native-reanimated";

interface Props {
	onClose: () => void;
}

function formatTime(seconds: number) {
	if (!seconds || isNaN(seconds)) return "0:00";
	const m = Math.floor(seconds / 60);
	const s = Math.floor(seconds % 60);
	return `${m}:${s < 10 ? "0" : ""}${s}`;
}

export default function FullScreenPlayer({ onClose }: Props) {
	const { currentVideo, queue, removeFromQueue, playVideo, player, isLoading } =
		usePlayer();
	const [showQueue, setShowQueue] = useState(false);

	const videoRef = useRef<VideoView>(null);

	const [isNativeFullscreen, setIsNativeFullscreen] = useState(false);

	const isPlayingEvent = useEvent(player, "playingChange", {
		isPlaying: player.playing,
	});
	const playbackRateEvent = useEvent(player, "playbackRateChange", {
		playbackRate: player.playbackRate,
	});
	const [currentTime, setCurrentTime] = useState(0);

	useEffect(() => {
		// Use manual interval to sync time since useEvent for timeUpdate might not trigger fast enough or needs explicit config
		const interval = setInterval(() => {
			if (player) {
				if (player.playing) {
					setCurrentTime(player.currentTime);
				}

				// Prevent constant stalling when catching up to a live stream
				if (
					player.isLive &&
					player.playbackRate > 1 &&
					(player.currentOffsetFromLive ?? 0) < 15
				) {
					player.playbackRate = 1;
				}
			}
		}, 500);
		return () => clearInterval(interval);
	}, [player]);

	const colorScheme = useColorScheme();
	const colors =
		Colors[colorScheme === "unspecified" ? "light" : (colorScheme ?? "light")];
	const insets = useSafeAreaInsets();

	if (!currentVideo) return null;

	const isPlaying = isPlayingEvent.isPlaying;
	const isLive = player.isLive;
	const liveOffset = player.currentOffsetFromLive ?? 0;

	let duration =
		currentVideo.durationSeconds > 0
			? currentVideo.durationSeconds
			: (player.duration ?? 0);
	if (isLive) {
		duration = currentTime + liveOffset;
	}
	if (isNaN(duration) || duration <= 0) {
		duration = 0;
	}

	const remainingTime = Math.max(0, duration - currentTime);

	const queueOpacity = useAnimatedStyle(
		() => ({
			opacity: withTiming(showQueue ? 1 : 0, { duration: 150 }),
			zIndex: showQueue ? 10 : 0,
		}),
		[showQueue],
	);

	const playerOpacity = useAnimatedStyle(
		() => ({
			opacity: withTiming(showQueue ? 0 : 1, { duration: 150 }),
		}),
		[showQueue],
	);

	const screenHeight = Dimensions.get("window").height;
	const screenWidth = Dimensions.get("window").width;
	const sheetHeight = screenHeight * PLAYER_SHEET_FRACTION;

	return (
		<View
			style={[
				styles.container,
				{
					height: sheetHeight,
					paddingTop: 24,
					paddingBottom: insets.bottom + 32,
					width: screenWidth,
					justifyContent: "space-between",
				},
			]}
		>
			{/* Blurred Background that bleeds outside to handle over-drag */}
			<Image
				source={{ uri: currentVideo.thumbnailUrl }}
				style={[
					StyleSheet.absoluteFill,
					{ top: -screenHeight, height: screenHeight * 3 },
				]}
				blurRadius={80}
			/>
			<View
				style={[
					StyleSheet.absoluteFill,
					{
						backgroundColor: "rgba(0,0,0,0.5)",
						top: -screenHeight,
						height: screenHeight * 3,
					},
				]}
			/>

			{/* Custom Drag Indicator */}
			<View
				style={{
					width: "100%",
					alignItems: "center",
					marginBottom: 16,
					marginTop: -4,
				}}
			>
				<View
					style={{
						width: 40,
						height: 5,
						borderRadius: 2.5,
						backgroundColor: "rgba(255,255,255,0.4)",
					}}
				/>
			</View>

			{/* Top Section: Art or Queue */}
			<View style={{ flex: 1, width: "100%", justifyContent: "flex-start" }}>
				{/* Player View (Always mounted for performance, toggled via opacity) */}
				<Animated.View
					style={[{ width: "100%", position: "absolute" }, playerOpacity]}
					pointerEvents={showQueue ? "none" : "auto"}
				>
					<View style={styles.artContainer}>
						<VideoView
							ref={videoRef}
							player={player}
							style={styles.albumArt}
							nativeControls={true}
							contentFit="cover"
							fullscreenOptions={{ enable: true, orientation: "landscape" }}
							onFullscreenEnter={() => setIsNativeFullscreen(true)}
							onFullscreenExit={() => setIsNativeFullscreen(false)}
						/>
						{isLoading && (
							<View
								style={[
									StyleSheet.absoluteFill,
									{
										justifyContent: "center",
										alignItems: "center",
										backgroundColor: "rgba(0,0,0,0.4)",
										borderRadius: 12,
									},
								]}
							>
								<ActivityIndicator size="large" color="#FFF" />
							</View>
						)}
					</View>

					<View
						style={[
							styles.infoContainer,
							{
								flexDirection: "row",
								alignItems: "center",
								justifyContent: "space-between",
							},
						]}
					>
						<View style={{ flex: 1, marginRight: 32 }}>
							<ThemedText
								type="subtitle"
								numberOfLines={1}
								style={[styles.title, { color: "#FFF" }]}
							>
								{currentVideo.title}
							</ThemedText>
							<ThemedText
								type="default"
								numberOfLines={1}
								style={{ color: "rgba(255,255,255,0.7)", fontSize: 14 }}
							>
								{currentVideo.channelName || "YouTube Audio"}
							</ThemedText>
						</View>
						<Host
							matchContents
							style={{
								overflow: "visible",
								height: 36,
								justifyContent: "center",
							}}
						>
							<Button
								label="Queue"
								systemImage="list.bullet"
								onPress={() => setShowQueue(!showQueue)}
								modifiers={[
									labelStyle("iconOnly"),
									font({ size: 16, weight: "semibold" }),
									tint("#FFF"),
									frame({ width: 36, height: 36 }),
									glassEffect({
										glass: { variant: "regular", interactive: true },
										shape: "ellipse",
									}),
								]}
							/>
						</Host>
					</View>
				</Animated.View>

				{/* Queue View */}
				<Animated.View
					style={[
						styles.queueContainer,
						{
							height: "100%",
							position: "absolute",
							width: screenWidth,
							left: -24,
						},
						queueOpacity,
					]}
					pointerEvents={showQueue ? "auto" : "none"}
				>
					<View
						style={{
							flexDirection: "row",
							alignItems: "center",
							marginTop: -8,
							marginBottom: 20,
							paddingHorizontal: 24,
						}}
					>
						<Host
							matchContents
							style={{
								overflow: "visible",
								marginRight: 12,
								marginLeft: -4,
								height: 36,
								justifyContent: "center",
							}}
						>
							<Button
								label="Close"
								systemImage="chevron.backward"
								onPress={() => setShowQueue(false)}
								modifiers={[
									labelStyle("iconOnly"),
									font({ size: 16, weight: "semibold" }),
									tint("#FFF"),
									frame({ width: 36, height: 36 }),
									glassEffect({
										glass: { variant: "regular", interactive: true },
										shape: "ellipse",
									}),
								]}
							/>
						</Host>
						<ThemedText
							style={[styles.queueHeader, { color: "#FFF", marginBottom: 0 }]}
						>
							Coda
						</ThemedText>
					</View>

					{queue.length === 0 ? (
						<View
							style={{
								flex: 1,
								justifyContent: "center",
								alignItems: "center",
								paddingTop: 16,
							}}
						>
							<ThemedText themeColor="textSecondary">
								La coda è vuota
							</ThemedText>
						</View>
					) : (
						<Host style={{ flex: 1 }}>
							<List
								modifiers={[
									listStyle("plain"),
									scrollContentBackground("hidden"),
									listRowSpacing(12),
								]}
							>
								<List.ForEach>
									{queue.map((item, index) => (
										<SwipeActions
											key={item.videoId}
											modifiers={[
												listRowSeparator("hidden"),
												listRowBackground("transparent"),
												listRowInsets({
													top: 0,
													bottom: 0,
													leading: 20,
													trailing: 24,
												}),
												frame({ height: 63 }),
											]}
										>
											<Pressable
												style={[styles.queueItem, { width: screenWidth - 44 }]}
												onPress={() => {
													setShowQueue(false);
													playVideo(item);
													removeFromQueue?.(index);
												}}
											>
												<Image
													source={{ uri: item.thumbnailUrl }}
													style={styles.queueItemThumb}
												/>
												<View style={styles.queueItemInfo}>
													<ThemedText
														style={styles.queueItemTitle}
														numberOfLines={1}
													>
														{item.title}
													</ThemedText>
													<View style={styles.queueItemSubRow}>
														<ThemedText
															style={styles.queueItemAuthor}
															themeColor="textSecondary"
															numberOfLines={1}
														>
															{item.channelName}
														</ThemedText>
														<ThemedText
															style={styles.queueItemDuration}
															themeColor="textSecondary"
														>
															{item.duration}
														</ThemedText>
													</View>
												</View>
											</Pressable>
											<SwipeActions.Actions edge="trailing" allowsFullSwipe>
												<Button
													role="destructive"
													onPress={() => removeFromQueue?.(index)}
												>
													<SwiftUI_Image
														systemName="trash"
														color="white"
														size={20}
													/>
												</Button>
											</SwipeActions.Actions>
										</SwipeActions>
									))}
								</List.ForEach>
							</List>
						</Host>
					)}
				</Animated.View>
			</View>

			{/* Progress Bar */}
			{/* Progress Bar (Removed in favor of native controls) */}
		</View>
	);
}

const styles = StyleSheet.create({
	container: {
		flex: 1,
		paddingHorizontal: 24,
	},
	header: {
		paddingBottom: 16,
		alignItems: "center",
	},
	closeIndicatorArea: {
		paddingVertical: 12,
		width: "100%",
		alignItems: "center",
	},
	dragIndicator: {
		width: 40,
		height: 5,
		borderRadius: 2.5,
		opacity: 0.3,
	},
	artContainer: {
		width: "100%",
		aspectRatio: 16 / 9,
		borderRadius: 16,
		overflow: "hidden",
		shadowColor: "#000",
		shadowOffset: { width: 0, height: 10 },
		shadowOpacity: 0.3,
		shadowRadius: 20,
		elevation: 10,
		backgroundColor: "#333",
		position: "relative",
	},
	overlayContainer: {
		position: "absolute",
		bottom: 8,
		left: 8,
		right: 8,
		flexDirection: "row",
		justifyContent: "space-between",
		alignItems: "center",
	},
	overlayChip: {
		borderRadius: 20,
		overflow: "hidden",
	},
	overlayCircle: {
		borderRadius: 14,
		overflow: "hidden",
		width: 28,
		height: 28,
		justifyContent: "center",
		alignItems: "center",
	},
	albumArt: {
		width: "100%",
		height: "100%",
	},
	infoContainer: {
		marginTop: 12,
		marginBottom: 8,
	},
	title: {
		fontSize: 18,
		fontWeight: "bold",
		marginBottom: -8,
	},
	progressContainer: {
		marginBottom: 32,
		marginTop: 4,
	},
	progressBarBackground: {
		width: "100%",
		justifyContent: "center",
	},
	progressBarFill: {
		height: "100%",
		borderRadius: 3,
	},
	timeContainer: {
		flexDirection: "row",
		justifyContent: "space-between",
		marginTop: 8,
	},

	controlButton: {
		padding: 16,
	},
	playPauseButton: {
		padding: 16,
	},
	bottomActionsContainer: {
		flexDirection: "row",
		justifyContent: "space-between",
		alignItems: "center",
		paddingHorizontal: 16,
		paddingTop: 16,
		width: "100%",
	},
	queueContainer: {
		flex: 1,
		marginBottom: 24,
	},
	queueHeader: {
		fontSize: 24,
		lineHeight: 28,
		fontWeight: "bold",
		marginBottom: 16,
	},
	queueItem: {
		flexDirection: "row",
		alignItems: "center",
	},
	queueItemThumb: {
		width: 112,
		height: 63,
		borderRadius: 8,
		marginRight: 12,
		flexShrink: 0,
	},
	queueItemInfo: {
		flexGrow: 1,
		flexShrink: 1,
		width: 0,
		justifyContent: "space-between",
		alignSelf: "stretch",
	},
	queueItemTitle: {
		fontSize: 16,
		fontWeight: "600",
		marginBottom: 4,
	},
	queueItemAuthor: {
		fontSize: 14,
		flex: 1,
	},
	queueItemSubRow: {
		flexDirection: "row",
		alignItems: "center",
		justifyContent: "space-between",
	},
	queueItemDuration: {
		fontSize: 14,
		marginLeft: 8,
	},
});
