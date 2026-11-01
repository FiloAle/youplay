import { DarkTheme, DefaultTheme, ThemeProvider } from "expo-router";
import { useColorScheme } from "react-native";

import AppTabs from "@/components/app-tabs";
import PlayerOverlay from "@/components/player/PlayerOverlay";
import { PlayerProvider } from "@/contexts/PlayerContext";
import { SubscriptionProvider } from "@/contexts/SubscriptionContext";
import { GestureHandlerRootView } from "react-native-gesture-handler";

export default function TabLayout() {
	const colorScheme = useColorScheme();
	return (
		<GestureHandlerRootView style={{ flex: 1 }}>
			<ThemeProvider value={colorScheme === "dark" ? DarkTheme : DefaultTheme}>
				<SubscriptionProvider>
					<PlayerProvider>
						<AppTabs />
						<PlayerOverlay />
					</PlayerProvider>
				</SubscriptionProvider>
			</ThemeProvider>
		</GestureHandlerRootView>
	);
}
