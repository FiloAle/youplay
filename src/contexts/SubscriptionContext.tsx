import { ChannelInfo, youtubeService } from "@/lib/youtube";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system/legacy";
import * as Sharing from "expo-sharing";
import {
	createContext,
	ReactNode,
	useContext,
	useEffect,
	useState,
} from "react";
import { Alert } from "react-native";

// File visible in the iOS Files app under "On My iPhone > YouTube Podcasts"
const BACKUP_FILE_PATH = FileSystem.documentDirectory + "subscriptions-backup.json";

const isValidBackup = (data: unknown): data is ChannelInfo[] =>
	Array.isArray(data) &&
	data.every((ch) => typeof ch.id === "string" && typeof ch.name === "string");

interface SubscriptionContextType {
	subscriptions: ChannelInfo[];
	toggleSubscription: (channel: ChannelInfo) => void;
	isSubscribed: (id: string) => boolean;
	refreshSubscriptions: () => Promise<void>;
	exportSubscriptions: () => Promise<void>;
	importSubscriptions: () => Promise<void>;
}

const SubscriptionContext = createContext<SubscriptionContextType | null>(null);

export function SubscriptionProvider({ children }: { children: ReactNode }) {
	const [subscriptions, setSubscriptions] = useState<ChannelInfo[]>([]);

	useEffect(() => {
		const loadSubscriptions = async () => {
			try {
				const stored = await AsyncStorage.getItem("subscriptions");
				if (stored) {
					setSubscriptions(JSON.parse(stored));
					return;
				}
				// AsyncStorage empty (e.g. fresh install) → try auto-restore from Documents backup
				const fileInfo = await FileSystem.getInfoAsync(BACKUP_FILE_PATH);
				if (fileInfo.exists) {
					const content = await FileSystem.readAsStringAsync(BACKUP_FILE_PATH, {
						encoding: FileSystem.EncodingType.UTF8,
					});
					const parsed = JSON.parse(content);
					if (isValidBackup(parsed) && parsed.length > 0) {
						await AsyncStorage.setItem("subscriptions", content);
						setSubscriptions(parsed);
					}
				}
			} catch (e) {
				console.error("Failed to load subscriptions", e);
			}
		};
		loadSubscriptions();
	}, []);

	// Persists to AsyncStorage AND keeps the Documents backup in sync.
	const saveSubscriptions = async (newSubs: ChannelInfo[]) => {
		setSubscriptions(newSubs);
		const json = JSON.stringify(newSubs, null, 2);
		try {
			await AsyncStorage.setItem("subscriptions", json);
		} catch (e) {
			console.error("Failed to save subscriptions to AsyncStorage", e);
		}
		// Always keep the Documents backup up-to-date (best-effort)
		try {
			await FileSystem.writeAsStringAsync(BACKUP_FILE_PATH, json, {
				encoding: FileSystem.EncodingType.UTF8,
			});
		} catch (e) {
			console.warn("Failed to write Documents backup", e);
		}
	};

	const toggleSubscription = (channel: ChannelInfo) => {
		const isSub = subscriptions.some((s) => s.id === channel.id);
		const newSubs = isSub
			? subscriptions.filter((s) => s.id !== channel.id)
			: [...subscriptions, channel];
		saveSubscriptions(newSubs);
	};

	const isSubscribed = (id: string) => subscriptions.some((s) => s.id === id);

	const refreshSubscriptions = async () => {
		if (subscriptions.length === 0) return;
		try {
			const results = await Promise.allSettled(
				subscriptions.map((sub) => youtubeService.getChannelInfo(sub.id)),
			);
			const updatedSubs = subscriptions.map((sub, i) => {
				const result = results[i];
				return result.status === "fulfilled" ? result.value : sub;
			});
			await saveSubscriptions(updatedSubs);
		} catch (e) {
			console.error("Failed to refresh subscriptions", e);
		}
	};

	// Manual export: shares the Documents backup file via the iOS share sheet.
	const exportSubscriptions = async () => {
		if (subscriptions.length === 0) {
			Alert.alert("Nessun canale", "Non hai canali da esportare.");
			return;
		}
		try {
			// Ensure the file is up-to-date before sharing
			await FileSystem.writeAsStringAsync(
				BACKUP_FILE_PATH,
				JSON.stringify(subscriptions, null, 2),
				{ encoding: FileSystem.EncodingType.UTF8 },
			);
			await Sharing.shareAsync(BACKUP_FILE_PATH, {
				mimeType: "application/json",
				dialogTitle: "Esporta canali seguiti",
				UTI: "public.json",
			});
		} catch (e: any) {
			Alert.alert("Errore", e.message || "Impossibile esportare i canali.");
		}
	};

	// Manual import: pick any JSON file and merge it with existing subscriptions.
	const importSubscriptions = async () => {
		try {
			const result = await DocumentPicker.getDocumentAsync({
				type: "application/json",
				copyToCacheDirectory: true,
			});
			if (result.canceled) return;

			const content = await FileSystem.readAsStringAsync(result.assets[0].uri, {
				encoding: FileSystem.EncodingType.UTF8,
			});
			const parsed = JSON.parse(content);
			if (!isValidBackup(parsed)) {
				Alert.alert("File non valido", "Il file selezionato non è un backup valido.");
				return;
			}
			const existingIds = new Set(subscriptions.map((s) => s.id));
			const newOnes = parsed.filter((ch) => !existingIds.has(ch.id));
			await saveSubscriptions([...subscriptions, ...newOnes]);
			Alert.alert(
				"Importazione completata",
				newOnes.length > 0
					? `${newOnes.length} canale/i aggiunto/i.`
					: "Tutti i canali erano già presenti.",
			);
		} catch (e: any) {
			Alert.alert("Errore", e.message || "Impossibile importare i canali.");
		}
	};

	return (
		<SubscriptionContext.Provider
			value={{
				subscriptions,
				toggleSubscription,
				isSubscribed,
				refreshSubscriptions,
				exportSubscriptions,
				importSubscriptions,
			}}
		>
			{children}
		</SubscriptionContext.Provider>
	);
}

export function useSubscriptions() {
	const context = useContext(SubscriptionContext);
	if (!context) {
		throw new Error("useSubscriptions must be used within a SubscriptionProvider");
	}
	return context;
}

