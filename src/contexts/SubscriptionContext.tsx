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

// File visible in the iOS Files app under "On My iPhone > YouPlay"
const BACKUP_FILE_PATH = FileSystem.documentDirectory + "subscriptions-backup.json";

export interface LocalCacheData {
	version: 2;
	channels: ChannelInfo[];
	categories: string[];
}

export interface BackupDataV3 {
	version: 3;
	channels: { id: string; category?: string }[];
	categories: string[];
}

const isValidOldBackup = (data: unknown): data is ChannelInfo[] =>
	Array.isArray(data) &&
	data.every((ch) => typeof ch.id === "string" && typeof ch.name === "string");

const isValidLocalCache = (data: unknown): data is LocalCacheData =>
	typeof data === "object" && data !== null &&
	(data as any).version === 2 &&
	Array.isArray((data as any).channels) &&
	Array.isArray((data as any).categories);

const isValidV3Backup = (data: unknown): data is BackupDataV3 =>
	typeof data === "object" && data !== null &&
	(data as any).version === 3 &&
	Array.isArray((data as any).channels) &&
	Array.isArray((data as any).categories);

interface SubscriptionContextType {
	subscriptions: ChannelInfo[];
	categories: string[];
	isImporting: boolean;
	toggleSubscription: (channel: ChannelInfo) => void;
	isSubscribed: (id: string) => boolean;
	refreshSubscriptions: () => Promise<void>;
	exportSubscriptions: () => Promise<void>;
	importSubscriptions: () => Promise<void>;
	addCategory: (name: string) => void;
	setChannelCategory: (id: string, category: string | null) => void;
	createAndSetCategory: (id: string, categoryName: string) => void;
	removeCategory: (categoryName: string) => void;
}

const SubscriptionContext = createContext<SubscriptionContextType | null>(null);

export function SubscriptionProvider({ children }: { children: ReactNode }) {
	const [subscriptions, setSubscriptions] = useState<ChannelInfo[]>([]);
	const [categories, setCategories] = useState<string[]>([]);
	const [isImporting, setIsImporting] = useState(false);

	useEffect(() => {
		const loadSubscriptions = async () => {
			try {
				const stored = await AsyncStorage.getItem("subscriptions");
				if (stored) {
					const parsed = JSON.parse(stored);
					if (isValidLocalCache(parsed)) {
						setSubscriptions(parsed.channels);
						setCategories(parsed.categories);
					} else if (isValidOldBackup(parsed)) {
						setSubscriptions(parsed);
					}
					return;
				}
				// AsyncStorage empty (e.g. fresh install) → try auto-restore from Documents backup
				const fileInfo = await FileSystem.getInfoAsync(BACKUP_FILE_PATH);
				if (fileInfo.exists) {
					const content = await FileSystem.readAsStringAsync(BACKUP_FILE_PATH, {
						encoding: FileSystem.EncodingType.UTF8,
					});
					const parsed = JSON.parse(content);
					if (isValidLocalCache(parsed)) {
						await AsyncStorage.setItem("subscriptions", content);
						setSubscriptions(parsed.channels);
						setCategories(parsed.categories);
					} else if (isValidOldBackup(parsed)) {
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
	const saveData = async (newSubs: ChannelInfo[], newCats: string[]) => {
		setSubscriptions(newSubs);
		setCategories(newCats);
		const data: LocalCacheData = { version: 2, channels: newSubs, categories: newCats };
		const json = JSON.stringify(data, null, 2);
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
		saveData(newSubs, categories);
	};

	const addCategory = (name: string) => {
		if (name.trim() && !categories.includes(name.trim())) {
			saveData(subscriptions, [...categories, name.trim()]);
		}
	};

	const setChannelCategory = (id: string, category: string | null) => {
		const newSubs = subscriptions.map((s) => {
			if (s.id === id) {
				return category ? { ...s, category } : { ...s, category: undefined };
			}
			return s;
		});
		saveData(newSubs, categories);
	};

	const createAndSetCategory = (id: string, categoryName: string) => {
		const trimmed = categoryName.trim();
		if (!trimmed) return;
		
		const newCats = categories.includes(trimmed) ? categories : [...categories, trimmed];
		const newSubs = subscriptions.map((s) => {
			if (s.id === id) {
				return { ...s, category: trimmed };
			}
			return s;
		});
		
		saveData(newSubs, newCats);
	};

	const removeCategory = (categoryName: string) => {
		const newCats = categories.filter((c) => c !== categoryName);
		const newSubs = subscriptions.map((s) => {
			if (s.category === categoryName) {
				return { ...s, category: undefined };
			}
			return s;
		});
		saveData(newSubs, newCats);
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
				return result.status === "fulfilled" ? { ...result.value, category: sub.category } : sub;
			});
			await saveData(updatedSubs, categories);
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
			const data: BackupDataV3 = { 
				version: 3, 
				channels: subscriptions.map(s => ({ id: s.id, category: s.category })), 
				categories 
			};
			await FileSystem.writeAsStringAsync(
				BACKUP_FILE_PATH,
				JSON.stringify(data, null, 2),
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

			setIsImporting(true);

			const content = await FileSystem.readAsStringAsync(result.assets[0].uri, {
				encoding: FileSystem.EncodingType.UTF8,
			});
			const parsed = JSON.parse(content);
			
			if (isValidV3Backup(parsed)) {
				const existingIds = new Set(subscriptions.map((s) => s.id));
				const newOnes = parsed.channels.filter((ch) => !existingIds.has(ch.id));
				
				// Fetch metadata for new channels
				const results = await Promise.allSettled(
					newOnes.map(ch => youtubeService.getChannelInfo(ch.id))
				);
				
				const fetchedChannels = results
					.map((res, i) => res.status === "fulfilled" ? { ...res.value, category: newOnes[i].category } : null)
					.filter(Boolean) as ChannelInfo[];
				
				const existingCats = new Set(categories);
				const newCats = parsed.categories.filter((c) => !existingCats.has(c));
				
				await saveData([...subscriptions, ...fetchedChannels], [...categories, ...newCats]);
				Alert.alert("Successo", "Canali e categorie importati correttamente.");
			} else if (isValidOldBackup(parsed)) {
				const existingIds = new Set(subscriptions.map((s) => s.id));
				const newOnes = parsed.filter((ch) => !existingIds.has(ch.id));
				await saveData([...subscriptions, ...newOnes], categories);
				Alert.alert("Successo", "Canali importati correttamente (formato v1).");
			} else {
				Alert.alert("File non valido", "Il file selezionato non è un backup valido.");
				return;
			}
		} catch (e: any) {
			Alert.alert("Errore", e.message || "Impossibile importare i canali.");
		} finally {
			setIsImporting(false);
		}
	};

	return (
		<SubscriptionContext.Provider
			value={{
				subscriptions,
				categories,
				isImporting,
				toggleSubscription,
				isSubscribed,
				refreshSubscriptions,
				exportSubscriptions,
				importSubscriptions,
				addCategory,
				setChannelCategory,
				createAndSetCategory,
				removeCategory,
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

