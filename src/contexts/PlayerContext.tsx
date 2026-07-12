import { VideoInfo, youtubeService } from "@/lib/youtube";
import { setAudioModeAsync } from "expo-audio";
import { useVideoPlayer } from "expo-video";
import React, {
	createContext,
	ReactNode,
	useContext,
	useEffect,
	useState,
} from "react";
import { Alert, View } from "react-native";

interface PlayerContextType {
	currentVideo: VideoInfo | null;
	playVideo: (video: VideoInfo) => Promise<void>;
	pause: () => void;
	resume: () => void;
	seekTo: (time: number) => void;
	isLoading: boolean;
	player: any;
	queue: VideoInfo[];
	addToQueue: (video: VideoInfo) => void;
	removeFromQueue: (index: number) => void;
	playNext: () => Promise<void>;
}

const PlayerContext = createContext<PlayerContextType | null>(null);

export function PlayerProvider({ children }: { children: ReactNode }) {
	const [currentVideo, setCurrentVideo] = useState<VideoInfo | null>(null);
	const [isLoading, setIsLoading] = useState(false);
	const [queue, setQueue] = useState<VideoInfo[]>([]);

	const player = useVideoPlayer(null);

	useEffect(() => {
		setAudioModeAsync({
			playsInSilentMode: true,
			shouldPlayInBackground: true,
			interruptionMode: "doNotMix",
		});
	}, []);

	const queueRef = React.useRef<VideoInfo[]>([]);
	const playNextLock = React.useRef(false);

	const playNext = async () => {
		if (playNextLock.current) return;
		playNextLock.current = true;

		setTimeout(() => {
			playNextLock.current = false;
		}, 5000);

		if (queueRef.current.length > 0) {
			const nextVideo = queueRef.current[0];
			queueRef.current = queueRef.current.slice(1);
			setQueue(queueRef.current);
			await playVideo(nextVideo);
		} else {
			player.pause();
			player.currentTime = 0;
		}
	};

	useEffect(() => {
		const sub1 = player.addListener("statusChange", (payload) => {
			if (payload.status === "error") {
				Alert.alert(
					"Errore Riproduzione",
					"Il player nativo ha rifiutato lo stream video.",
				);
				setCurrentVideo(null);
			}
		});

		const sub2 = player.addListener("playToEnd", () => {
			playNext();
		});

		return () => {
			sub1.remove();
			sub2.remove();
		};
	}, [player]);

	const addToQueue = (video: VideoInfo) => {
		queueRef.current = [...queueRef.current, video];
		setQueue(queueRef.current);
	};

	const removeFromQueue = (index: number) => {
		const newQueue = [...queueRef.current];
		newQueue.splice(index, 1);
		queueRef.current = newQueue;
		setQueue(newQueue);
	};

	const playVideo = async (video: VideoInfo) => {
		setIsLoading(true);
		setCurrentVideo(video);

		try {
			const streamInfo = await youtubeService.getAudioStream(video.videoId);
			if (streamInfo && streamInfo.url) {
				await player.replaceAsync(streamInfo.url);
				player.play();
				// expo-video supporta i metadata per il control center
				player.showNowPlayingNotification = true;
				// In SDK 56 potremmo dover usare moduli specifici per i metadati,
				// ma per ora avviamo lo stream
			} else {
				Alert.alert("Errore", "Nessun flusso compatibile trovato.");
				setCurrentVideo(null);
			}
		} catch (e: any) {
			Alert.alert("Errore", e.message || "Impossibile riprodurre.");
			setCurrentVideo(null);
		} finally {
			setIsLoading(false);
		}
	};

	const pause = () => {
		player.pause();
	};

	const resume = () => {
		player.play();
	};

	const seekTo = (time: number) => {
		player.currentTime = time;
	};

	return (
		<PlayerContext.Provider
			value={{
				currentVideo,
				playVideo,
				pause,
				resume,
				seekTo,
				isLoading,
				player,
				queue,
				addToQueue,
				removeFromQueue,
				playNext,
			}}
		>
			{children}
		</PlayerContext.Provider>
	);
}

export function usePlayer() {
	const context = useContext(PlayerContext);
	if (!context) {
		throw new Error("usePlayer must be used within a PlayerProvider");
	}
	return context;
}
