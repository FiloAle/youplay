import { SFSymbol, SymbolView } from "expo-symbols";
import React from "react";
import { StyleSheet, Text, View } from "react-native";

interface EmptyStateProps {
	icon: SFSymbol;
	title: string;
	subtitle: string;
}

export default function EmptyState({ icon, title, subtitle }: EmptyStateProps) {
	return (
		<View style={styles.emptyContainer}>
			<SymbolView name={icon} size={64} tintColor="#666" />
			<Text style={styles.emptyText}>{title}</Text>
			<Text style={styles.emptySubtext}>{subtitle}</Text>
		</View>
	);
}

const styles = StyleSheet.create({
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
