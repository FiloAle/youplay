import { ThemedText } from "@/components/themed-text";
import { SymbolView } from "expo-symbols";
import { Colors, PLAYER_SHEET_FRACTION } from "@/constants/theme";
import { usePlayer } from "@/contexts/PlayerContext";
import { useEvent } from "expo";
import { VideoView } from "expo-video";
import { Button, Host } from "@expo/ui/swift-ui";
import { buttonStyle, font, tint } from "@expo/ui/swift-ui/modifiers";
import { useEffect, useState, useRef } from "react";
import {
	Dimensions,
	Image,
	StyleSheet,
	View,
	useColorScheme,
} from "react-native";
import {
	FlatList,
	PanGestureHandler,
	Pressable,
	State,
} from "react-native-gesture-handler";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { GlassView } from "expo-glass-effect";

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
	const {
		currentVideo,
		pause,
		resume,
		seekTo,
		queue,
		removeFromQueue,
		playVideo,
		player,
		isVideoMode,
		toggleVideoMode,
	} = usePlayer();
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
				if (player.isLive && player.playbackRate > 1 && (player.currentOffsetFromLive ?? 0) < 15) {
					player.playbackRate = 1;
				}
			}
		}, 500);
		return () => clearInterval(interval);
	}, [player]);

	const currentSpeed =
		playbackRateEvent?.playbackRate ?? player.playbackRate ?? 1;



	const colorScheme = useColorScheme();
	const colors =
		Colors[colorScheme === "unspecified" ? "light" : (colorScheme ?? "light")];
	const insets = useSafeAreaInsets();

	if (!currentVideo) return null;

	const isPlaying = isPlayingEvent.isPlaying;
	const isLive = player.isLive;
	const liveOffset = player.currentOffsetFromLive ?? 0;
	
	let duration = currentVideo.durationSeconds > 0 ? currentVideo.durationSeconds : (player.duration ?? 0);
	if (isLive) {
		duration = currentTime + liveOffset;
	}
	if (isNaN(duration) || duration <= 0) {
		duration = 0;
	}

	const handlePlayPause = () => {
		if (isPlaying) pause();
		else resume();
	};

	const skipBackward = () => {
		seekTo(Math.max(0, currentTime - 15));
	};

	const skipForward = () => {
		seekTo(Math.min(duration, currentTime + 15));
	};

	const [barWidth, setBarWidth] = useState(0);
	const [dragTime, setDragTime] = useState<number | null>(null);

	const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;
	const displayPercent =
		dragTime !== null && duration > 0
			? (dragTime / duration) * 100
			: progressPercent;
	const displayTime = dragTime !== null ? dragTime : currentTime;
	const remainingTime = Math.max(0, duration - displayTime);
	const isAtLiveEdge = isLive && remainingTime <= 15;

	const handleSpeedChange = () => {
		if (isAtLiveEdge) return;
		let nextSpeed = 1;
		if (currentSpeed < 1.5) nextSpeed = 1.5;
		else if (currentSpeed < 2) nextSpeed = 2;
		else if (currentSpeed < 2.5 && !isLive) nextSpeed = 2.5;
		else nextSpeed = 1;

		player.playbackRate = nextSpeed;
	};

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
					overflow: "hidden",
					justifyContent: "space-between",
				},
			]}
		>
			{/* Blurred Background */}
			<Image
				source={{ uri: currentVideo.thumbnailUrl }}
				style={StyleSheet.absoluteFill}
				blurRadius={80}
			/>
			<View
				style={[
					StyleSheet.absoluteFill,
					{ backgroundColor: "rgba(0,0,0,0.5)" },
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
				{showQueue ? (
					<View style={[styles.queueContainer, { maxHeight: 400 }]}>
						<ThemedText style={[styles.queueHeader, { color: "#FFF" }]}>
							Coda
						</ThemedText>
						<FlatList
							data={queue}
							keyExtractor={(item, idx) => item.videoId + idx.toString()}
							showsVerticalScrollIndicator={false}
							renderItem={({ item, index }) => (
								<Pressable
									style={styles.queueItem}
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
										<ThemedText style={styles.queueItemTitle} numberOfLines={2}>
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
							)}
							ListEmptyComponent={
								<ThemedText themeColor="textSecondary">
									La coda è vuota
								</ThemedText>
							}
						/>
					</View>
				) : (
					<View style={{ width: "100%" }}>
						<View style={styles.artContainer}>
							{isVideoMode ? (
								<VideoView
									ref={videoRef}
									player={player}
									style={styles.albumArt}
									nativeControls={isNativeFullscreen}
									contentFit="cover"
									fullscreenOptions={{ enable: true, orientation: "landscape" }}
									onFullscreenEnter={() => setIsNativeFullscreen(true)}
									onFullscreenExit={() => setIsNativeFullscreen(false)}
								/>
							) : (
								<Image
									source={{ uri: currentVideo.thumbnailUrl }}
									style={styles.albumArt}
									resizeMode="cover"
								/>
							)}

							{/* Overlays on cover */}
							<View style={styles.overlayContainer}>
								{/* Left Chip */}
								<GlassView
									glassEffectStyle="regular"
									style={styles.overlayChip}
								>
									<Pressable
										onPress={() => toggleVideoMode()}
										style={{
											flexDirection: "row",
											alignItems: "center",
											paddingHorizontal: 10,
											height: 28,
											gap: 8,
										}}
									>
										<SymbolView
											name={isVideoMode ? "headphones" : "play.tv.fill"}
											size={14}
											weight="medium"
											tintColor="#FFFFFF"
										/>
										<ThemedText
											style={{
												fontSize: 14,
												fontWeight: "500",
												color: "#FFFFFF",
											}}
										>
											{isVideoMode ? "Passa al podcast" : "Passa al video"}
										</ThemedText>
									</Pressable>
								</GlassView>

								{/* Right Fullscreen Button */}
								{isVideoMode && (
									<GlassView
										glassEffectStyle="regular"
										style={styles.overlayCircle}
									>
										<Pressable
											onPress={() => videoRef.current?.enterFullscreen()}
											style={{
												width: 28,
												height: 28,
												justifyContent: "center",
												alignItems: "center",
											}}
										>
											<SymbolView
												name="arrow.up.left.and.arrow.down.right"
												size={14}
												weight="medium"
												tintColor="#FFFFFF"
											/>
										</Pressable>
									</GlassView>
								)}
							</View>
						</View>

						<View style={styles.infoContainer}>
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
								style={{ color: "rgba(255,255,255,0.7)" }}
							>
								{currentVideo.channelName || "YouTube Audio"}
							</ThemedText>
						</View>
					</View>
				)}
			</View>

			{/* Progress Bar */}
			<View
				style={styles.progressContainer}
				onLayout={(e) => setBarWidth(e.nativeEvent.layout.width)}
			>
				<PanGestureHandler
					activeOffsetX={[-5, 5]}
					onGestureEvent={(e) => {
						if (barWidth > 0 && duration > 0) {
							let newTime = (e.nativeEvent.x / barWidth) * duration;
							setDragTime(Math.max(0, Math.min(newTime, duration)));
						}
					}}
					onHandlerStateChange={(e) => {
						if (
							e.nativeEvent.state === State.END ||
							e.nativeEvent.state === State.CANCELLED
						) {
							if (barWidth > 0 && duration > 0) {
								let newTime = (e.nativeEvent.x / barWidth) * duration;
								newTime = Math.max(0, Math.min(newTime, duration));
								if (isLive && newTime >= duration - 10) {
									newTime = Math.max(0, duration - 10);
								}
								seekTo(newTime);
								setDragTime(null);
								if (isPlaying) player.play();
							}
						}
					}}
				>
					<Pressable
						style={{ width: "100%", height: 40, justifyContent: "center" }}
						onPress={(e) => {
							if (barWidth > 0 && duration > 0) {
								let newTime = (e.nativeEvent.locationX / barWidth) * duration;
								newTime = Math.max(0, Math.min(newTime, duration));
								if (isLive && newTime >= duration - 10) {
									newTime = Math.max(0, duration - 10);
								}
								seekTo(newTime);
								if (isPlaying) player.play();
							}
						}}
					>
						{/* Custom visual progress bar */}
						<View
							style={{
								height: 6,
								borderRadius: 3,
								width: "100%",
								backgroundColor: "rgba(255,255,255,0.3)",
								position: "absolute",
								overflow: "hidden",
							}}
						>
							<View
								style={[
									styles.progressBarFill,
									{ width: `${displayPercent}%`, backgroundColor: "#FFF" },
								]}
							/>
						</View>
					</Pressable>
				</PanGestureHandler>
				<View style={[styles.timeContainer, { marginTop: -8 }]}>
					<ThemedText type="small" style={{ color: "rgba(255,255,255,0.7)" }}>
						{formatTime(displayTime)}
					</ThemedText>
					<ThemedText type="small" style={{ color: "rgba(255,255,255,0.7)" }}>
						{isLive && remainingTime <= 15 ? "DAL VIVO" : `-${formatTime(remainingTime)}`}
					</ThemedText>
				</View>
			</View>

			{/* Playback Controls & Bottom Actions */}
			<View style={styles.controlsContainer}>
				<Host
					style={{
						width: 44,
						height: 44,
						justifyContent: "center",
						alignItems: "center",
						opacity: isAtLiveEdge ? 0.4 : 1,
					}}
				>
					<Button
						label={`${currentSpeed}x`}
						onPress={handleSpeedChange}
						modifiers={[
							font({ size: 17, weight: "bold" }),
							tint("#FFF"),
							buttonStyle("plain"),
						]}
					/>
				</Host>

				<Host
					style={{
						width: 36,
						height: 36,
						justifyContent: "center",
						alignItems: "center",
					}}
				>
					<Button
						label=""
						systemImage="gobackward.15"
						onPress={skipBackward}
						modifiers={[font({ size: 26 }), tint("#FFF"), buttonStyle("plain")]}
					/>
				</Host>

				<Host
					style={{
						width: 60,
						height: 60,
						justifyContent: "center",
						alignItems: "center",
					}}
				>
					<Button
						label=""
						systemImage={isPlaying ? "pause.fill" : "play.fill"}
						onPress={handlePlayPause}
						modifiers={[font({ size: 48 }), tint("#FFF"), buttonStyle("plain")]}
					/>
				</Host>

				<Host
					style={{
						width: 36,
						height: 36,
						justifyContent: "center",
						alignItems: "center",
					}}
				>
					<Button
						label=""
						systemImage="goforward.15"
						onPress={skipForward}
						modifiers={[font({ size: 26 }), tint("#FFF"), buttonStyle("plain")]}
					/>
				</Host>

				<Host
					style={{
						width: 44,
						height: 44,
						justifyContent: "center",
						alignItems: "center",
					}}
				>
					<Button
						label=""
						systemImage="list.bullet"
						onPress={() => setShowQueue(!showQueue)}
						modifiers={[
							font({ size: 22 }),
							tint(showQueue ? "rgba(255,255,255,0.5)" : "#FFF"),
							buttonStyle("plain"),
						]}
					/>
				</Host>
			</View>
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
		fontSize: 22,
		fontWeight: "bold",
		marginBottom: -4,
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
	controlsContainer: {
		flexDirection: "row",
		alignItems: "center",
		justifyContent: "space-evenly",
		paddingHorizontal: 24,
		width: "100%",
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
		fontSize: 20,
		fontWeight: "bold",
		marginBottom: 16,
	},
	queueItem: {
		flexDirection: "row",
		alignItems: "center",
		marginBottom: 16,
	},
	queueItemThumb: {
		width: 130,
		aspectRatio: 16 / 9,
		borderRadius: 8,
		marginRight: 12,
	},
	queueItemInfo: {
		flex: 1,
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
