import { VideoInfo, youtubeService } from "@/lib/youtube";
import { setAudioModeAsync } from "expo-audio";
import { useVideoPlayer } from "expo-video";
import { useEvent } from "expo";
import AsyncStorage from "@react-native-async-storage/async-storage";
import React, {
	createContext,
	ReactNode,
	useContext,
	useEffect,
	useState,
} from "react";
import { Alert, View } from "react-native";
import ToastHUD from "@/components/ui/ToastHUD";

interface PlayerContextType {
	currentVideo: VideoInfo | null;
	playVideo: (video: VideoInfo, autoplay?: boolean) => Promise<void>;
	pause: () => void;
	resume: () => void;
	seekTo: (time: number) => void;
	isLoading: boolean;
	player: any;
	queue: VideoInfo[];
	history: VideoInfo[];
	addToQueue: (video: VideoInfo) => void;
	removeFromQueue: (index: number) => void;
	playNext: () => Promise<void>;
	playPrevious: () => Promise<void>;
}

const PlayerContext = createContext<PlayerContextType | null>(null);

export function PlayerProvider({ children }: { children: ReactNode }) {
	const [currentVideo, setCurrentVideo] = useState<VideoInfo | null>(null);
	const [isLoading, setIsLoading] = useState(false);
	const [queue, setQueue] = useState<VideoInfo[]>([]);
	const [history, setHistory] = useState<VideoInfo[]>([]);
	const [toastVisible, setToastVisible] = useState(false);
	const [toastMessage, setToastMessage] = useState("");

	const showToast = (message: string) => {
		setToastMessage(message);
		setToastVisible(true);
	};

	const player = useVideoPlayer(null);

	useEffect(() => {
		if (player) {
			player.staysActiveInBackground = true;
		}
		setAudioModeAsync({
			playsInSilentMode: true,
			shouldPlayInBackground: true,
			interruptionMode: "doNotMix",
		});
	}, [player]);

	const queueRef = React.useRef<VideoInfo[]>([]);
	const playNextLock = React.useRef(false);

	const playbackRateEvent = useEvent(player, "playbackRateChange");

	useEffect(() => {
		if (playbackRateEvent?.playbackRate) {
			AsyncStorage.setItem("player_playback_rate", playbackRateEvent.playbackRate.toString());
		}
	}, [playbackRateEvent?.playbackRate]);

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
		if (!currentVideo) {
			playVideo(video, false);
			showToast("Aggiunto alla coda");
		} else {
			queueRef.current = [...queueRef.current, video];
			setQueue(queueRef.current);
			showToast("Aggiunto alla coda");
		}
	};

	const removeFromQueue = (index: number) => {
		const newQueue = [...queueRef.current];
		newQueue.splice(index, 1);
		queueRef.current = newQueue;
		setQueue(newQueue);
	};

	const playVideo = async (video: VideoInfo, autoplay = true) => {
		if (currentVideo && currentVideo.videoId !== video.videoId) {
			setHistory((prev) => [...prev, currentVideo]);
		}
		setIsLoading(true);
		setCurrentVideo(video);
		player.pause();

		try {
			// Yield the JS thread to allow the MiniPlayer to mount and animations to start
			// This prevents the heavy youtubei.js parsing from freezing the UI (e.g. blocking the BottomSheet from opening)
			await new Promise(resolve => setTimeout(resolve, 50));

			const streamPromise = youtubeService.getAudioStream(video.videoId);
			
			const hq720 = `https://i.ytimg.com/vi/${video.videoId}/hq720.jpg`;
			const fallbackArtwork = `https://i.ytimg.com/vi/${video.videoId}/mqdefault.jpg`;
			const artworkPromise = fetch(hq720, { method: "HEAD" })
				.then(res => res.ok ? hq720 : fallbackArtwork)
				.catch(() => fallbackArtwork);

			const [streamInfo, bestArtwork] = await Promise.all([streamPromise, artworkPromise]);

			if (streamInfo && streamInfo.url) {
				await player.replaceAsync({
					uri: streamInfo.url,
					metadata: {
						title: video.title,
						artist: video.channelName || "YouTube Podcast",
						artwork: bestArtwork,
					}
				});
				
				const savedSpeed = await AsyncStorage.getItem("player_playback_rate");
				if (savedSpeed) {
					player.playbackRate = parseFloat(savedSpeed);
				}

				if (autoplay) {
					player.play();
				}
				player.showNowPlayingNotification = true;
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

	const playPrevious = async () => {
		if (player.currentTime > 3 || history.length === 0) {
			player.currentTime = 0;
			return;
		}
		const prev = history[history.length - 1];
		setHistory((prevHistory) => prevHistory.slice(0, -1));
		await playVideo(prev);
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
				history,
				addToQueue,
				removeFromQueue,
				playNext,
				playPrevious,
			}}
		>
			{children}
			<ToastHUD 
				visible={toastVisible} 
				message={toastMessage} 
				onHide={() => setToastVisible(false)} 
			/>
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
