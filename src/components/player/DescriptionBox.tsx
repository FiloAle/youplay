import { youtubeService } from "@/lib/youtube";
import { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";

const COLLAPSED_LINES = 3;

export default function DescriptionBox({ videoId }: { videoId: string }) {
	const [description, setDescription] = useState<string | null>(null);
	const [isExpanded, setIsExpanded] = useState(false);
	const [isTruncated, setIsTruncated] = useState(false);

	useEffect(() => {
		let aborted = false;
		setDescription(null);
		setIsExpanded(false);
		setIsTruncated(false);
		youtubeService
			.getVideoDescription(videoId)
			.catch(() => "")
			.then((text) => !aborted && setDescription(text));
		return () => {
			aborted = true;
		};
	}, [videoId]);

	if (description === "") return null;

	return (
		<View style={styles.box}>
			{description === null ? (
				<ActivityIndicator color="#888" />
			) : (
				<>
					{/* Invisible full-length copy, only used to know whether the text exceeds the collapsed height. */}
					<Text
						style={[styles.text, styles.measure]}
						onTextLayout={(e) => setIsTruncated(e.nativeEvent.lines.length > COLLAPSED_LINES)}
					>
						{description}
					</Text>
					<Text style={styles.text} numberOfLines={isExpanded ? undefined : COLLAPSED_LINES}>
						{description}
					</Text>
					{isTruncated && (
						<Pressable onPress={() => setIsExpanded((v) => !v)} hitSlop={8}>
							<Text style={styles.toggle}>{isExpanded ? "Mostra meno" : "Mostra di più"}</Text>
						</Pressable>
					)}
				</>
			)}
		</View>
	);
}

const styles = StyleSheet.create({
	box: {
		backgroundColor: "#1C1C1E",
		borderRadius: 12,
		padding: 12,
		gap: 6,
	},
	text: {
		color: "#DDD",
		fontSize: 14,
		lineHeight: 20,
	},
	measure: {
		position: "absolute",
		left: 12,
		right: 12,
		opacity: 0,
	},
	toggle: {
		color: "white",
		fontSize: 14,
		fontWeight: "600",
	},
});
