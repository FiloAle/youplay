import EmptyState from "@/components/EmptyState";
import { useSubscriptions } from "@/contexts/SubscriptionContext";
import { ChannelInfo } from "@/lib/youtube";
import { Button, ContextMenu, Host, Menu, Group } from "@expo/ui/swift-ui";
import { frame, tint, glassEffect, font, labelStyle } from "@expo/ui/swift-ui/modifiers";
import { Ionicons } from "@expo/vector-icons";
import { GlassView } from "expo-glass-effect";
import { Image } from "expo-image";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import { SymbolView } from "expo-symbols";
import React from "react";
import {
	Animated,
	Pressable,
	RefreshControl,
	StyleSheet,
	Text,
	View,
	Alert,
	ActivityIndicator,
} from "react-native";

export default function FollowedScreen() {
	const {
		subscriptions,
		categories,
		refreshSubscriptions,
		exportSubscriptions,
		importSubscriptions,
		isImporting,
		toggleSubscription,
		addCategory,
		setChannelCategory,
		createAndSetCategory,
	} = useSubscriptions();
	const [isRefreshing, setIsRefreshing] = React.useState(false);

	const scrollY = React.useRef(new Animated.Value(0)).current;

	const titleOpacity = scrollY.interpolate({
		inputRange: [0, 40],
		outputRange: [1, 0],
		extrapolate: "clamp",
	});

	const onRefresh = React.useCallback(async () => {
		setIsRefreshing(true);
		await refreshSubscriptions();
		setIsRefreshing(false);
	}, [refreshSubscriptions]);

	const renderChannel = ({ item }: { item: ChannelInfo }) => (
		<View style={styles.channelCard}>
			<View style={{ flex: 1 }}>
				<Host style={{ flex: 1 }}>
					<ContextMenu>
						<ContextMenu.Trigger>
							<Pressable
								style={{ flexDirection: "row", alignItems: "center" }}
								onPress={() => router.push(`/followed/channel/${item.id}`)}
							>
								<Image
									source={{ uri: item.thumbnail }}
									style={styles.channelThumbnail}
									contentFit="cover"
								/>
								<View style={styles.channelInfo}>
									<Text style={styles.channelName} numberOfLines={1}>
										{item.name}
									</Text>
									<Text style={styles.channelSubscribers}>{item.subscribers}</Text>
								</View>
							</Pressable>
						</ContextMenu.Trigger>

						<ContextMenu.Items>
							<Button
								role="destructive"
								onPress={() => {
									toggleSubscription({
										id: item.id,
										name: item.name,
										thumbnail: item.thumbnail,
										subscribers: item.subscribers,
										description: item.description || "",
									});
								}}
								systemImage="trash"
								label="Smetti di seguire"
							/>
						</ContextMenu.Items>
					</ContextMenu>
				</Host>
			</View>

			<View style={{ paddingLeft: 12 }}>
				<Host style={{ width: 34, height: 34 }}>
					<Menu
						label={
							<GlassView
								style={styles.iconButton}
								glassEffectStyle="regular"
								pointerEvents="none"
							>
								<SymbolView name="circle.grid.2x2" size={18} tintColor="#fff" />
							</GlassView>
						}
					>
					<Group>
						{categories.map((c) => (
							<Button
								key={c}
								label={c}
								systemImage={item.category === c ? "checkmark" : undefined}
								onPress={() => {
									if (item.category === c) {
										setChannelCategory(item.id, null);
									} else {
										setChannelCategory(item.id, c);
									}
								}}
							/>
						))}
					</Group>
					<Button
						label="Crea categoria..."
						systemImage="plus"
						onPress={() => {
							Alert.prompt(
								"Crea categoria",
								undefined,
								[
									{ text: "Annulla", style: "cancel" },
									{
										text: "Conferma",
										style: "default",
										isPreferred: true,
										onPress: (text?: string) => {
											if (text) {
												createAndSetCategory(item.id, text);
											}
										},
									},
								],
								"plain-text"
							);
						}}
					/>
				</Menu>
			</Host>
			</View>
		</View>
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
				<Text style={styles.headerTitle}>Seguiti</Text>
				<View style={styles.headerActions}>
					{isImporting ? (
						<View style={[styles.iconButton, { backgroundColor: "rgba(255,255,255,0.2)" }]}>
							<ActivityIndicator color="white" />
						</View>
					) : (
						<Host>
							<Menu
								label={
									<GlassView
										style={styles.iconButton}
										glassEffectStyle="regular"
										pointerEvents="none"
									>
										<SymbolView name="ellipsis" size={20} tintColor="#fff" />
									</GlassView>
								}
							>
								<Button
									onPress={importSubscriptions}
									systemImage="square.and.arrow.down"
									label="Importa"
								/>
								<Button
									onPress={exportSubscriptions}
									systemImage="square.and.arrow.up"
									label="Esporta"
								/>
							</Menu>
						</Host>
					)}
				</View>
			</Animated.View>

			{subscriptions.length === 0 ? (
				<EmptyState
					icon="rectangle.stack"
					title="Non segui ancora nessun canale"
					subtitle="Cerca i tuoi podcast preferiti e tocca 'Segui' per ritrovarli qui"
				/>
			) : (
				<Animated.FlatList
					data={subscriptions}
					keyExtractor={(item) => item.id}
					renderItem={renderChannel}
					contentContainerStyle={[styles.listContent, { paddingTop: 120 }]}
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
							tintColor="white"
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
		backgroundColor: "#000", // Apple Podcasts style dark background
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
	listContent: {
		paddingHorizontal: 20,
		paddingBottom: 100, // padding for miniplayer
	},
	channelCard: {
		flexDirection: "row",
		alignItems: "center",
		paddingVertical: 12,
		borderBottomWidth: StyleSheet.hairlineWidth,
		borderBottomColor: "#333",
	},
	channelThumbnail: {
		width: 50,
		height: 50,
		borderRadius: 25,
		backgroundColor: "#222",
	},
	channelInfo: {
		flex: 1,
		marginLeft: 16,
		justifyContent: "center",
	},
	channelName: {
		color: "white",
		fontSize: 16,
		fontWeight: "600",
		marginBottom: 4,
	},
	channelSubscribers: {
		color: "#aaa",
		fontSize: 13,
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
});
