import { usePlayer } from "@/contexts/PlayerContext";
import { VideoInfo } from "@/lib/youtube";
import { Ionicons } from "@expo/vector-icons";
import { Image } from "expo-image";
import { SymbolView } from "expo-symbols";
import { Pressable, StyleSheet, Text, View } from "react-native";

interface EpisodeCardProps {
	video: VideoInfo;
	/** Text shown below the title (e.g. channel name or view count) */
	subtitle?: string;
	/** Called when subtitle is tapped (e.g. navigate to channel) */
	onSubtitlePress?: () => void;
}

export default function EpisodeCard({
	video,
	subtitle,
	onSubtitlePress,
}: EpisodeCardProps) {
	const { openVideo, addToQueue } = usePlayer();

	return (
		<Pressable
			style={({ pressed }) => [styles.container, pressed && styles.pressed]}
			onPress={() => openVideo(video)}
		>
			<View style={styles.topRow}>
				<Image
					source={{ uri: video.thumbnailUrl }}
					style={styles.thumbnail}
					contentFit="cover"
				/>
				<View style={styles.info}>
					<Text style={styles.title} numberOfLines={2}>
						{video.title}
					</Text>
					{!!subtitle &&
						(onSubtitlePress ? (
							<Pressable onPress={onSubtitlePress}>
								<Text style={styles.subtitle}>{subtitle}</Text>
							</Pressable>
						) : (
							<Text style={styles.subtitle}>{subtitle}</Text>
						))}
				</View>
			</View>
			<View style={styles.actions}>
				<View style={styles.playAndDateContainer}>
					<View style={styles.playButton}>
						<Ionicons name="play" size={14} color="#FF383C" />
						<Text style={styles.playButtonText}>{video.duration}</Text>
					</View>
					<Text style={styles.dateInline}>{video.publishedDate}</Text>
				</View>
				<Pressable style={styles.queueButton} onPress={() => addToQueue(video)}>
					<SymbolView
						name="text.line.last.and.arrowtriangle.forward"
						size={24}
						tintColor="#666"
					/>
				</Pressable>
			</View>
		</Pressable>
	);
}

const styles = StyleSheet.create({
	container: {
		marginBottom: 16,
		paddingBottom: 16,
		borderBottomWidth: StyleSheet.hairlineWidth,
		borderBottomColor: "#333",
	},
	pressed: {
		opacity: 0.6,
	},
	topRow: {
		flexDirection: "row",
		marginBottom: 20,
	},
	thumbnail: {
		width: 112,
		aspectRatio: 16 / 9,
		borderRadius: 8,
		backgroundColor: "#222",
		marginRight: 12,
	},
	info: {
		flex: 1,
		justifyContent: "space-between",
		paddingVertical: 2,
	},
	title: {
		color: "white",
		fontSize: 16,
		fontWeight: "600",
		lineHeight: 20,
	},
	subtitle: {
		color: "#aaa",
		fontSize: 13,
	},
	actions: {
		flexDirection: "row",
		alignItems: "center",
		justifyContent: "space-between",
	},
	playAndDateContainer: {
		flexDirection: "row",
		alignItems: "center",
	},
	dateInline: {
		color: "#aaa",
		fontSize: 13,
		marginLeft: 12,
		textTransform: "uppercase",
	},
	playButton: {
		flexDirection: "row",
		alignItems: "center",
		justifyContent: "center",
		backgroundColor: "#FF383C22",
		paddingVertical: 6,
		paddingHorizontal: 12,
		borderRadius: 16,
	},
	playButtonText: {
		color: "#FF383C",
		fontSize: 13,
		fontWeight: "600",
		marginLeft: 6,
	},
	queueButton: {
		padding: 6,
	},
});
