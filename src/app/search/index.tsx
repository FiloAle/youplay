import EmptyState from "@/components/EmptyState";
import { ChannelInfo, youtubeService } from "@/lib/youtube";
import { Host, TextField, useNativeState } from "@expo/ui/swift-ui";
import { foregroundStyle } from "@expo/ui/swift-ui/modifiers";
import { GlassView } from "expo-glass-effect";
import { Image } from "expo-image";
import { LinearGradient } from "expo-linear-gradient";
import { useRouter } from "expo-router";
import { SymbolView } from "expo-symbols";
import React, { useCallback, useEffect, useState } from "react";
import {
	ActivityIndicator,
	Animated,
	Pressable,
	StyleSheet,
	Text,
	View,
} from "react-native";

export default function SearchScreen() {
	const router = useRouter();
	const [query, setQuery] = useState("");
	const queryState = useNativeState("");
	const [debouncedQuery, setDebouncedQuery] = useState("");
	const [results, setResults] = useState<ChannelInfo[]>([]);
	const [isLoading, setIsLoading] = useState(false);
	const [error, setError] = useState("");

	const scrollY = React.useRef(new Animated.Value(0)).current;

	const titleOpacity = scrollY.interpolate({
		inputRange: [0, 40],
		outputRange: [1, 0],
		extrapolate: "clamp",
	});

	// Animate search bar up until it hits the safe area (top: 60)
	const searchBarTranslateY = scrollY.interpolate({
		inputRange: [0, 60],
		outputRange: [0, -60],
		extrapolate: "clamp",
	});

	// Debounce query
	useEffect(() => {
		const timer = setTimeout(() => setDebouncedQuery(query), 500);
		return () => clearTimeout(timer);
	}, [query]);

	// Perform search
	useEffect(() => {
		if (!debouncedQuery) {
			setResults([]);
			return;
		}

		const search = async () => {
			setIsLoading(true);
			setError("");
			try {
				const data = await youtubeService.searchChannels(debouncedQuery);
				setResults(data);
			} catch (err: any) {
				setError(err.message || "Errore nella ricerca");
			} finally {
				setIsLoading(false);
			}
		};

		search();
	}, [debouncedQuery]);

	const renderChannel = useCallback(
		({ item }: { item: ChannelInfo }) => (
			<Pressable
				style={({ pressed }) => [
					styles.channelItem,
					pressed && styles.channelItemPressed,
				]}
				onPress={() => router.push(`/search/channel/${item.id}`)}
			>
				<Image
					source={{ uri: item.thumbnail }}
					style={styles.thumbnail}
					contentFit="cover"
				/>
				<View style={styles.channelInfo}>
					<Text style={styles.channelName} numberOfLines={1}>
						{item.name}
					</Text>
					<Text style={styles.channelSubscribers}>{item.subscribers}</Text>
					<Text style={styles.channelDescription} numberOfLines={2}>
						{item.description}
					</Text>
				</View>
			</Pressable>
		),
		[router],
	);

	const renderEmptyState = () => {
		if (isLoading && results.length === 0) {
			return (
				<View style={styles.centerContainer}>
					<ActivityIndicator size="large" color="#fff" />
				</View>
			);
		}
		if (error) {
			return (
				<EmptyState
					icon="exclamationmark.triangle"
					title="Errore"
					subtitle={error}
				/>
			);
		}
		if (debouncedQuery) {
			return (
				<EmptyState
					icon="magnifyingglass"
					title="Nessun canale trovato"
					subtitle="Prova a cercare qualcos'altro"
				/>
			);
		}
		return (
			<EmptyState
				icon="magnifyingglass"
				title="Effettua una ricerca"
				subtitle="Inizia a digitare per cercare canali, podcast e molto altro"
			/>
		);
	};

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
				<Text style={styles.headerTitle}>Cerca</Text>
			</Animated.View>

			<Animated.View
				style={[
					styles.searchBarWrapper,
					{ transform: [{ translateY: searchBarTranslateY }] },
				]}
			>
				<GlassView style={styles.searchBarContainer} glassEffectStyle="regular">
					<SymbolView
						name="magnifyingglass"
						size={20}
						tintColor="#888"
						style={styles.searchIcon}
					/>
					<Host style={{ flex: 1, minHeight: 44, justifyContent: "center" }}>
						<TextField
							text={queryState}
							placeholder="Cerca podcast, canali..."
							onTextChange={setQuery}
							modifiers={[foregroundStyle("white")]}
						/>
					</Host>
				</GlassView>
			</Animated.View>

			{results.length === 0 ? (
				renderEmptyState()
			) : (
				<Animated.FlatList
					data={results}
					keyExtractor={(item) => item.id}
					renderItem={renderChannel}
					contentContainerStyle={[styles.listContent, { paddingTop: 180 }]}
					indicatorStyle="white"
					onScroll={Animated.event(
						[{ nativeEvent: { contentOffset: { y: scrollY } } }],
						{ useNativeDriver: true },
					)}
					scrollEventThrottle={16}
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
		height: 180,
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
	searchBarWrapper: {
		position: "absolute",
		top: 120,
		left: 16,
		right: 16,
		zIndex: 20,
	},
	searchBarContainer: {
		flexDirection: "row",
		alignItems: "center",
		borderRadius: 64,
		overflow: "hidden",
		paddingHorizontal: 12,
		height: 44,
	},
	searchIcon: {
		marginRight: 8,
	},
	searchInput: {
		flex: 1,
		color: "white",
		fontSize: 17,
	},
	centerContainer: {
		flex: 1,
		justifyContent: "center",
		alignItems: "center",
		padding: 40,
	},
	listContent: {
		flexGrow: 1,
		paddingHorizontal: 16,
		paddingBottom: 100, // padding for miniplayer
	},
	channelItem: {
		flexDirection: "row",
		alignItems: "center",
		paddingVertical: 12,
		borderBottomWidth: StyleSheet.hairlineWidth,
		borderBottomColor: "#333",
	},
	channelItemPressed: {
		opacity: 0.7,
	},
	thumbnail: {
		width: 64,
		height: 64,
		borderRadius: 8, // slight rounding like podcast covers
		marginRight: 16,
		backgroundColor: "#222",
	},
	channelInfo: {
		flex: 1,
		justifyContent: "center",
	},
	channelName: {
		color: "#fff",
		fontSize: 17,
		fontWeight: "600",
		marginBottom: 4,
	},
	channelSubscribers: {
		color: "#999",
		fontSize: 14,
		marginBottom: 4,
	},
	channelDescription: {
		color: "#666",
		fontSize: 13,
	},
	errorText: {
		color: "#ff453a",
		fontSize: 16,
	},
	emptyText: {
		color: "#999",
		fontSize: 16,
	},
});
