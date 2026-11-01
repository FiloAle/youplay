import { usePlayerActions, usePlayerState } from "@/contexts/PlayerContext";
import {
	Button,
	Host,
	List,
	SwipeActions,
	Image as SwiftUI_Image,
} from "@expo/ui/swift-ui";
import {
	environment,
	frame,
	listRowBackground,
	listRowInsets,
	listRowSeparator,
	listStyle,
	scrollContentBackground,
} from "@expo/ui/swift-ui/modifiers";
import { Image } from "expo-image";
import { SymbolView } from "expo-symbols";
import { memo, useEffect, useRef, useState } from "react";
import { Pressable, StyleSheet, Text, useWindowDimensions, View } from "react-native";
import Animated, {
	Easing,
	Extrapolation,
	interpolate,
	useAnimatedStyle,
	useSharedValue,
	withTiming,
} from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";

export interface Rect {
	x: number;
	y: number;
	width: number;
	height: number;
}

interface QueuePanelProps {
	visible: boolean;
	/** Frame (window coordinates) the panel grows from and shrinks back into. */
	origin: Rect | null;
	onClose: () => void;
}

const ANIMATION = { duration: 320, easing: Easing.out(Easing.cubic) };

/** Covers the area below the video, expanding from (and collapsing into) the queue button. */
function QueuePanel({ visible, origin, onClose }: QueuePanelProps) {
	const { queue } = usePlayerState();
	const { removeFromQueue, openVideo } = usePlayerActions();
	const { width } = useWindowDimensions();
	const insets = useSafeAreaInsets();
	const containerRef = useRef<View>(null);
	const [bounds, setBounds] = useState<Rect | null>(null);
	const progress = useSharedValue(0);

	useEffect(() => {
		if (!visible) {
			progress.value = withTiming(0, ANIMATION);
			return;
		}
		// Measure right before opening: the container moves with the player while it's dragged.
		containerRef.current?.measureInWindow((x, y, w, h) => {
			setBounds({ x, y, width: w, height: h });
			progress.value = withTiming(1, ANIMATION);
		});
	}, [visible]);

	const start = bounds && {
		x: (origin?.x ?? bounds.x + bounds.width - 52) - bounds.x,
		y: (origin?.y ?? bounds.y + 12) - bounds.y,
		width: origin?.width ?? 36,
		height: origin?.height ?? 36,
	};

	const panelStyle = useAnimatedStyle(() => {
		if (!start || !bounds) return { opacity: 0 };
		const p = progress.value;
		return {
			opacity: interpolate(p, [0, 0.15], [0, 1], Extrapolation.CLAMP),
			left: interpolate(p, [0, 1], [start.x, 0]),
			top: interpolate(p, [0, 1], [start.y, 0]),
			width: interpolate(p, [0, 1], [start.width, bounds.width]),
			height: interpolate(p, [0, 1], [start.height, bounds.height]),
			borderRadius: interpolate(p, [0, 1], [start.height / 2, 0]),
		};
	});

	// Content keeps its final layout and gets revealed by the growing panel, instead of being squashed.
	const contentStyle = useAnimatedStyle(() => {
		if (!start || !bounds) return {};
		const p = progress.value;
		return {
			opacity: interpolate(p, [0.4, 1], [0, 1], Extrapolation.CLAMP),
			left: -interpolate(p, [0, 1], [start.x, 0]),
			top: -interpolate(p, [0, 1], [start.y, 0]),
			width: bounds.width,
			height: bounds.height,
		};
	});

	return (
		<View
			ref={containerRef}
			style={StyleSheet.absoluteFill}
			pointerEvents={visible ? "box-none" : "none"}
			collapsable={false}
		>
			<Animated.View style={[styles.panel, panelStyle]}>
				<Animated.View style={[styles.content, { paddingBottom: insets.bottom }, contentStyle]}>
					<View style={styles.header}>
						<Text style={styles.headerTitle}>Coda</Text>
						<Pressable onPress={onClose} hitSlop={8} accessibilityLabel="Chiudi coda">
							<SymbolView name="xmark" size={18} weight="semibold" tintColor="white" />
						</Pressable>
					</View>

					{queue.length === 0 ? (
						<Text style={styles.empty}>La coda è vuota</Text>
					) : (
						<Host style={styles.list}>
							<List
								modifiers={[
									listStyle("plain"),
									scrollContentBackground("hidden"),
									environment("colorScheme", "dark"),
								]}
							>
								{queue.map((item, index) => (
									<SwipeActions
										key={item.videoId}
										modifiers={[
											listRowSeparator("hidden"),
											listRowBackground("transparent"),
											listRowInsets({ top: 6, bottom: 6, leading: 16, trailing: 16 }),
											frame({ height: 75 }),
										]}
									>
										<Pressable
											style={[styles.item, { width: width - 32 }]}
											onPress={() => {
												removeFromQueue(index);
												openVideo(item);
											}}
										>
											<Image source={{ uri: item.thumbnailUrl }} style={styles.thumb} />
											<View style={styles.info}>
												<Text style={styles.title} numberOfLines={2}>
													{item.title}
												</Text>
												<Text style={styles.meta} numberOfLines={1}>
													{item.channelName} • {item.duration}
												</Text>
											</View>
										</Pressable>
										<SwipeActions.Actions edge="trailing" allowsFullSwipe>
											<Button role="destructive" onPress={() => removeFromQueue(index)}>
												<SwiftUI_Image systemName="trash" color="white" size={20} />
											</Button>
										</SwipeActions.Actions>
									</SwipeActions>
								))}
							</List>
						</Host>
					)}
				</Animated.View>
			</Animated.View>
		</View>
	);
}

export default memo(QueuePanel);

const styles = StyleSheet.create({
	panel: {
		position: "absolute",
		overflow: "hidden",
		backgroundColor: "black",
	},
	content: {
		position: "absolute",
	},
	header: {
		flexDirection: "row",
		alignItems: "center",
		justifyContent: "space-between",
		paddingHorizontal: 16,
		height: 60,
	},
	headerTitle: {
		color: "white",
		fontSize: 20,
		fontWeight: "700",
	},
	empty: {
		color: "#8E8E93",
		fontSize: 15,
		textAlign: "center",
		marginTop: 32,
	},
	list: {
		flex: 1,
	},
	item: {
		flexDirection: "row",
		alignItems: "center",
	},
	thumb: {
		width: 112,
		height: 63,
		borderRadius: 8,
		marginRight: 12,
	},
	info: {
		flex: 1,
		gap: 4,
	},
	title: {
		color: "white",
		fontSize: 15,
		fontWeight: "600",
		lineHeight: 19,
	},
	meta: {
		color: "#AAA",
		fontSize: 13,
	},
});
