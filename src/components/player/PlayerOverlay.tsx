import { usePlayerActions, usePlayerExpanded, usePlayerState } from "@/contexts/PlayerContext";
import { Button, Host } from "@expo/ui/swift-ui";
import { buttonStyle, font, tint } from "@expo/ui/swift-ui/modifiers";
import { useEvent } from "expo";
import { VideoView } from "expo-video";
import { useCallback, useEffect, useState } from "react";
import {
	ActivityIndicator,
	StyleSheet,
	Text,
	useWindowDimensions,
	View,
} from "react-native";
import { Gesture, GestureDetector } from "react-native-gesture-handler";
import Animated, {
	Extrapolation,
	interpolate,
	useAnimatedStyle,
	useSharedValue,
	withSpring,
} from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { scheduleOnRN, scheduleOnUI } from "react-native-worklets";
import PlayerDetails from "./PlayerDetails";
import QueuePanel, { Rect } from "./QueuePanel";

const MINI_HEIGHT = 64;
const MINI_MARGIN = 8;
const MINI_BOTTOM = 90; // Above the tab bar
const MINI_VIDEO_WIDTH = 100;
const MINI_VIDEO_HEIGHT = MINI_VIDEO_WIDTH * (9 / 16);
const MINI_VIDEO_RADIUS = 10;
const SPRING = { damping: 24, stiffness: 240, mass: 0.9, overshootClamping: true };

/**
 * Full-page player that collapses into a mini player by dragging the video down (and back up).
 * `progress` goes from 0 (expanded) to 1 (mini).
 *
 * The animation only touches transform, opacity and border radius, so it runs on the UI thread with no
 * layout pass: every layer keeps its full-page size and the native video view is never resized.
 */
export default function PlayerOverlay() {
	const { currentVideo, isLoading } = usePlayerState();
	const isExpanded = usePlayerExpanded();
	const { setExpanded, player, pause, resume, playNext } = usePlayerActions();
	const { width, height } = useWindowDimensions();
	const insets = useSafeAreaInsets();
	const [showQueue, setShowQueue] = useState(false);
	const [queueOrigin, setQueueOrigin] = useState<Rect | null>(null);
	// Expensive native changes (controls, content fit) wait for the animation to end.
	const [isSettledExpanded, setSettledExpanded] = useState(isExpanded);
	const { isPlaying } = useEvent(player, "playingChange", { isPlaying: player.playing });

	const progress = useSharedValue(isExpanded ? 0 : 1);
	const target = useSharedValue(isExpanded ? 0 : 1);
	const dragStart = useSharedValue(0);

	const videoHeight = width * (9 / 16);
	const miniTop = height - MINI_BOTTOM - MINI_HEIGHT;
	const miniVideoScale = MINI_VIDEO_WIDTH / width;

	const springTo = (value: number, velocity = 0) => {
		"worklet";
		target.value = value;
		progress.value = withSpring(value, { ...SPRING, velocity }, (finished) => {
			if (finished) scheduleOnRN(setSettledExpanded, value === 0);
		});
	};

	// Skipped when a gesture already started this spring, which would otherwise restart with no velocity.
	const syncWithState = (value: number) => {
		"worklet";
		if (target.value !== value) springTo(value);
	};

	useEffect(() => {
		scheduleOnUI(syncWithState, isExpanded ? 0 : 1);
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
			const value =
				Math.abs(e.velocityY) > 500 ? (e.velocityY > 0 ? 1 : 0) : progress.value > 0.5 ? 1 : 0;
			springTo(value, velocity);
			scheduleOnRN(setExpanded, value === 0);
		});

	// Native gesture so that reopening starts right away, even while the JS thread is busy.
	const createExpandTap = () =>
		Gesture.Tap()
			.enabled(!isExpanded)
			.onEnd((_e, success) => {
				if (!success) return;
				springTo(0);
				scheduleOnRN(setExpanded, true);
			});

	const backdropStyle = useAnimatedStyle(() => ({
		opacity: interpolate(progress.value, [0.85, 1], [1, 0], Extrapolation.CLAMP),
		transform: [
			{ translateY: interpolate(progress.value, [0, 1], [0, miniTop], Extrapolation.CLAMP) },
			{
				scaleX: interpolate(
					progress.value,
					[0, 1],
					[1, (width - MINI_MARGIN * 2) / width],
					Extrapolation.CLAMP,
				),
			},
			{ scaleY: interpolate(progress.value, [0, 1], [1, MINI_HEIGHT / height], Extrapolation.CLAMP) },
		],
	}));

	const detailsStyle = useAnimatedStyle(() => ({
		opacity: interpolate(progress.value, [0, 0.3], [1, 0], Extrapolation.CLAMP),
		transform: [
			{ translateY: interpolate(progress.value, [0, 1], [0, miniTop], Extrapolation.CLAMP) },
		],
	}));

	// Only moves while visible: at the top of the screen, a SwiftUI Host mounted here would pick up the safe area inset.
	const miniCardStyle = useAnimatedStyle(() => ({
		opacity: interpolate(progress.value, [0.7, 1], [0, 1], Extrapolation.CLAMP),
		transform: [
			{
				translateY: interpolate(progress.value, [0.7, 1], [-0.3 * miniTop, 0], Extrapolation.CLAMP),
			},
		],
	}));

	const videoStyle = useAnimatedStyle(() => ({
		borderRadius: interpolate(
			progress.value,
			[0, 1],
			[0, MINI_VIDEO_RADIUS / miniVideoScale],
			Extrapolation.CLAMP,
		),
		transform: [
			{ translateX: interpolate(progress.value, [0, 1], [0, MINI_MARGIN + 4], Extrapolation.CLAMP) },
			{
				translateY: interpolate(
					progress.value,
					[0, 1],
					[insets.top, miniTop + (MINI_HEIGHT - MINI_VIDEO_HEIGHT) / 2],
					Extrapolation.CLAMP,
				),
			},
			{ scale: interpolate(progress.value, [0, 1], [1, miniVideoScale], Extrapolation.CLAMP) },
		],
	}));

	const openQueue = useCallback((origin: Rect) => {
		setQueueOrigin(origin);
		setShowQueue(true);
	}, []);

	const closeQueue = useCallback(() => setShowQueue(false), []);

	if (!currentVideo) return null;

	return (
		<View style={StyleSheet.absoluteFill} pointerEvents="box-none">
			<Animated.View style={[styles.backdrop, backdropStyle]} pointerEvents="none" />

			<Animated.View
				style={[styles.details, { top: insets.top + videoHeight }, detailsStyle]}
				pointerEvents={isExpanded ? "auto" : "none"}
			>
				<PlayerDetails video={currentVideo} onOpenQueue={openQueue} />
				<QueuePanel visible={showQueue} origin={queueOrigin} onClose={closeQueue} />
			</Animated.View>

			<GestureDetector gesture={pan}>
				<View style={StyleSheet.absoluteFill} pointerEvents="box-none" collapsable={false}>
					{/* Keeps the area above the video draggable. */}
					<View
						style={[styles.topDragArea, { height: insets.top }]}
						pointerEvents={isExpanded ? "auto" : "none"}
						collapsable={false}
					/>

					<Animated.View
						style={[styles.miniCard, { top: miniTop }, miniCardStyle]}
						pointerEvents={isExpanded ? "none" : "box-none"}
					>
						<GestureDetector gesture={createExpandTap()}>
							<View style={styles.miniInfo} collapsable={false}>
								<Text style={styles.miniTitle} numberOfLines={1}>
									{currentVideo.title}
								</Text>
								<Text style={styles.miniSubtitle} numberOfLines={1}>
									{currentVideo.channelName}
								</Text>
							</View>
						</GestureDetector>
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

					<GestureDetector gesture={createExpandTap()}>
						<Animated.View style={[styles.video, { width, height: videoHeight }, videoStyle]}>
							<VideoView
								player={player}
								style={StyleSheet.absoluteFill}
								nativeControls={isSettledExpanded}
								contentFit={isSettledExpanded ? "contain" : "cover"}
								fullscreenOptions={{ enable: true, orientation: "landscape" }}
							/>
							{isLoading && isExpanded && (
								<View style={styles.loadingOverlay}>
									<ActivityIndicator size="large" color="white" />
								</View>
							)}
						</Animated.View>
					</GestureDetector>
				</View>
			</GestureDetector>
		</View>
	);
}

const styles = StyleSheet.create({
	backdrop: {
		...StyleSheet.absoluteFill,
		backgroundColor: "#000000",
		transformOrigin: "top",
	},
	details: {
		position: "absolute",
		left: 0,
		right: 0,
		bottom: 0,
	},
	topDragArea: {
		position: "absolute",
		top: 0,
		left: 0,
		right: 0,
	},
	video: {
		position: "absolute",
		top: 0,
		left: 0,
		overflow: "hidden",
		backgroundColor: "black",
		transformOrigin: "left top",
	},
	loadingOverlay: {
		...StyleSheet.absoluteFill,
		justifyContent: "center",
		alignItems: "center",
		backgroundColor: "rgba(0,0,0,0.4)",
	},
	miniCard: {
		position: "absolute",
		left: MINI_MARGIN,
		right: MINI_MARGIN,
		height: MINI_HEIGHT,
		paddingLeft: MINI_VIDEO_WIDTH + 12,
		paddingRight: 8,
		flexDirection: "row",
		alignItems: "center",
		gap: 8,
		borderRadius: 20,
		backgroundColor: "#1C1C1E",
		shadowColor: "#000",
		shadowOpacity: 0.3,
		shadowRadius: 10,
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
