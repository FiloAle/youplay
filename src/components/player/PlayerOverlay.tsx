import { usePlayer } from "@/contexts/PlayerContext";
import { Button, Host } from "@expo/ui/swift-ui";
import { buttonStyle, font, tint } from "@expo/ui/swift-ui/modifiers";
import { useEvent } from "expo";
import { VideoView } from "expo-video";
import { useEffect, useState } from "react";
import {
	ActivityIndicator,
	Pressable,
	StyleSheet,
	Text,
	useWindowDimensions,
	View,
} from "react-native";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import Animated, {
	Extrapolation,
	interpolate,
	interpolateColor,
	useAnimatedStyle,
	useSharedValue,
	withSpring,
} from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { scheduleOnRN } from "react-native-worklets";
import PlayerDetails from "./PlayerDetails";
import QueuePanel, { Rect } from "./QueuePanel";

const MINI_HEIGHT = 64;
const MINI_MARGIN = 8;
const MINI_BOTTOM = 90; // Above the tab bar
const MINI_VIDEO_WIDTH = 100;
const MINI_VIDEO_HEIGHT = MINI_VIDEO_WIDTH * (9 / 16);
const SPRING = { damping: 24, stiffness: 240, mass: 0.9 };

/**
 * Full-page player that collapses into a mini player by dragging the video down (and back up).
 * `progress` goes from 0 (expanded) to 1 (mini).
 */
export default function PlayerOverlay() {
	const { currentVideo, isExpanded, setExpanded, player, isLoading, pause, resume, playNext } =
		usePlayer();
	const { width, height } = useWindowDimensions();
	const insets = useSafeAreaInsets();
	const [showQueue, setShowQueue] = useState(false);
	const [queueOrigin, setQueueOrigin] = useState<Rect | null>(null);
	const { isPlaying } = useEvent(player, "playingChange", { isPlaying: player.playing });

	const progress = useSharedValue(isExpanded ? 0 : 1);
	const dragStart = useSharedValue(0);

	const videoHeight = width * (9 / 16);
	const miniTop = height - MINI_BOTTOM - MINI_HEIGHT;

	useEffect(() => {
		progress.value = withSpring(isExpanded ? 0 : 1, SPRING);
		if (!isExpanded) setShowQueue(false);
	}, [isExpanded]);

	const pan = Gesture.Pan()
		.activeOffsetY([-10, 10])
		.failOffsetX([-20, 20])
		.onStart(() => {
			dragStart.value = progress.value;
		})
		.onUpdate((e) => {
			progress.value = Math.min(1, Math.max(0, dragStart.value + e.translationY / miniTop));
		})
		.onEnd((e) => {
			const velocity = e.velocityY / miniTop;
			const target =
				Math.abs(e.velocityY) > 500 ? (e.velocityY > 0 ? 1 : 0) : progress.value > 0.5 ? 1 : 0;
			progress.value = withSpring(target, { ...SPRING, velocity });
			scheduleOnRN(setExpanded, target === 0);
		});

	const containerStyle = useAnimatedStyle(() => ({
		top: interpolate(progress.value, [0, 1], [0, miniTop]),
		left: interpolate(progress.value, [0, 1], [0, MINI_MARGIN]),
		right: interpolate(progress.value, [0, 1], [0, MINI_MARGIN]),
		height: interpolate(progress.value, [0, 1], [height, MINI_HEIGHT]),
		borderRadius: interpolate(progress.value, [0, 1], [0, 20]),
		backgroundColor: interpolateColor(progress.value, [0, 1], ["#000000", "#1C1C1E"]),
	}));

	const dragAreaStyle = useAnimatedStyle(() => ({
		height: interpolate(progress.value, [0, 1], [insets.top + videoHeight, MINI_HEIGHT]),
	}));

	const videoStyle = useAnimatedStyle(() => ({
		top: interpolate(progress.value, [0, 1], [insets.top, (MINI_HEIGHT - MINI_VIDEO_HEIGHT) / 2]),
		left: interpolate(progress.value, [0, 1], [0, 4]),
		width: interpolate(progress.value, [0, 1], [width, MINI_VIDEO_WIDTH]),
		height: interpolate(progress.value, [0, 1], [videoHeight, MINI_VIDEO_HEIGHT]),
		borderRadius: interpolate(progress.value, [0, 1], [0, 10]),
	}));

	const detailsStyle = useAnimatedStyle(() => ({
		opacity: interpolate(progress.value, [0, 0.3], [1, 0], Extrapolation.CLAMP),
	}));

	const miniControlsStyle = useAnimatedStyle(() => ({
		opacity: interpolate(progress.value, [0.7, 1], [0, 1], Extrapolation.CLAMP),
	}));

	if (!currentVideo) return null;

	return (
		<Animated.View style={[styles.container, containerStyle]}>
			<Animated.View
				style={[styles.details, { top: insets.top + videoHeight }, detailsStyle]}
				pointerEvents={isExpanded ? "auto" : "none"}
			>
				<PlayerDetails
					video={currentVideo}
					onOpenQueue={(origin) => {
						setQueueOrigin(origin);
						setShowQueue(true);
					}}
				/>
				<QueuePanel visible={showQueue} origin={queueOrigin} onClose={() => setShowQueue(false)} />
			</Animated.View>

			<GestureDetector gesture={pan}>
				<Animated.View style={[styles.dragArea, dragAreaStyle]}>
					<Animated.View
						style={[styles.miniControls, miniControlsStyle]}
						pointerEvents={isExpanded ? "none" : "auto"}
					>
						<Pressable style={styles.miniInfo} onPress={() => setExpanded(true)}>
							<Text style={styles.miniTitle} numberOfLines={1}>
								{currentVideo.title}
							</Text>
							<Text style={styles.miniSubtitle} numberOfLines={1}>
								{currentVideo.channelName}
							</Text>
						</Pressable>
						{isLoading ? (
							<ActivityIndicator style={styles.miniButton} color="white" />
						) : (
							<Host style={styles.miniButton}>
								<Button
									label=""
									systemImage={isPlaying ? "pause.fill" : "play.fill"}
									onPress={isPlaying ? pause : resume}
									modifiers={[font({ size: 22 }), tint("white"), buttonStyle("borderless")]}
								/>
							</Host>
						)}
						<Host style={styles.miniButton}>
							<Button
								label=""
								systemImage="forward.fill"
								onPress={() => playNext()}
								modifiers={[font({ size: 18 }), tint("white"), buttonStyle("borderless")]}
							/>
						</Host>
					</Animated.View>

					<Animated.View style={[styles.video, videoStyle]}>
						<VideoView
							player={player}
							style={StyleSheet.absoluteFill}
							nativeControls={isExpanded}
							contentFit={isExpanded ? "contain" : "cover"}
							fullscreenOptions={{ enable: true, orientation: "landscape" }}
						/>
						{isLoading && isExpanded && (
							<View style={styles.loadingOverlay}>
								<ActivityIndicator size="large" color="white" />
							</View>
						)}
						{!isExpanded && (
							<Pressable style={StyleSheet.absoluteFill} onPress={() => setExpanded(true)} />
						)}
					</Animated.View>
				</Animated.View>
			</GestureDetector>

		</Animated.View>
	);
}

const styles = StyleSheet.create({
	container: {
		position: "absolute",
		overflow: "hidden",
		shadowColor: "#000",
		shadowOpacity: 0.3,
		shadowRadius: 10,
	},
	details: {
		position: "absolute",
		left: 0,
		right: 0,
		bottom: 0,
	},
	dragArea: {
		position: "absolute",
		top: 0,
		left: 0,
		right: 0,
	},
	video: {
		position: "absolute",
		overflow: "hidden",
		backgroundColor: "black",
	},
	loadingOverlay: {
		...StyleSheet.absoluteFill,
		justifyContent: "center",
		alignItems: "center",
		backgroundColor: "rgba(0,0,0,0.4)",
	},
	miniControls: {
		position: "absolute",
		top: 0,
		bottom: 0,
		left: MINI_VIDEO_WIDTH + 12,
		right: 8,
		flexDirection: "row",
		alignItems: "center",
		gap: 8,
	},
	miniInfo: {
		flex: 1,
		justifyContent: "center",
		height: "100%",
	},
	miniTitle: {
		color: "white",
		fontSize: 14,
		fontWeight: "600",
	},
	miniSubtitle: {
		color: "#AAA",
		fontSize: 12,
		marginTop: 2,
	},
	miniButton: {
		width: 36,
		height: 36,
	},
});
