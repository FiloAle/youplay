import { useStableCallback } from "@/hooks/use-stable-callback";
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
	useMemo,
	useState,
} from "react";
import { Alert } from "react-native";
import ToastHUD from "@/components/ui/ToastHUD";

interface PlayerState {
	currentVideo: VideoInfo | null;
	isLoading: boolean;
	queue: VideoInfo[];
	history: VideoInfo[];
	maxQuality: number;
}

/** Every function here keeps the same identity across renders, so reading them never causes a re-render. */
interface PlayerActions {
	player: any;
	playVideo: (video: VideoInfo, autoplay?: boolean) => Promise<void>;
	pause: () => void;
	resume: () => void;
	seekTo: (time: number) => void;
	addToQueue: (video: VideoInfo) => void;
	removeFromQueue: (index: number) => void;
	playNext: () => Promise<void>;
	playPrevious: () => Promise<void>;
	setMaxQuality: (height: number) => void;
	setExpanded: (expanded: boolean) => void;
	/** Plays the video and opens the full-page player. */
	openVideo: (video: VideoInfo) => void;
}

const QUALITY_KEY = "player_max_quality";

const PlayerStateContext = createContext<PlayerState | null>(null);
const PlayerActionsContext = createContext<PlayerActions | null>(null);
const PlayerExpandedContext = createContext(false);

export function PlayerProvider({ children }: { children: ReactNode }) {
	const [currentVideo, setCurrentVideo] = useState<VideoInfo | null>(null);
	const [isLoading, setIsLoading] = useState(false);
	const [queue, setQueue] = useState<VideoInfo[]>([]);
	const [history, setHistory] = useState<VideoInfo[]>([]);
	const [toastVisible, setToastVisible] = useState(false);
	const [toastMessage, setToastMessage] = useState("");
	const [maxQuality, setMaxQualityState] = useState(0);
	const [isExpanded, setExpanded] = useState(false);

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

	useEffect(() => {
		AsyncStorage.getItem(QUALITY_KEY).then((saved) => {
			if (saved) setMaxQuality(parseInt(saved, 10));
		});
	}, []);

	const setMaxQuality = useStableCallback((height: number) => {
		setMaxQualityState(height);
		player.maxVideoHeight = height;
		AsyncStorage.setItem(QUALITY_KEY, height.toString());
	});

	const queueRef = React.useRef<VideoInfo[]>([]);
	const playNextLock = React.useRef(false);
	const autoplayPendingRef = React.useRef(false);

	const playbackRateEvent = useEvent(player, "playbackRateChange");

	useEffect(() => {
		if (playbackRateEvent?.playbackRate) {
			AsyncStorage.setItem(
				"player_playback_rate",
				playbackRateEvent.playbackRate.toString(),
			);
		}
	}, [playbackRateEvent?.playbackRate]);

	const playNext = useStableCallback(async () => {
		if (playNextLock.current) return;
		playNextLock.current = true;

		try {
			if (queueRef.current.length > 0) {
				const nextVideo = queueRef.current[0];
				queueRef.current = queueRef.current.slice(1);
				setQueue(queueRef.current);
				await playVideo(nextVideo);
			} else {
				player.pause();
				player.currentTime = 0;
			}
		} finally {
			playNextLock.current = false;
		}
	});

	useEffect(() => {
		const sub1 = player.addListener("statusChange", (payload) => {
			if (payload.status === "error") {
				Alert.alert(
					"Errore Riproduzione",
					"Il player nativo ha rifiutato lo stream video.",
				);
				clearCurrentVideo();
			} else if (payload.status === "readyToPlay") {
				if (autoplayPendingRef.current) {
					autoplayPendingRef.current = false;
					player.play();
				}
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

	const addToQueue = useStableCallback((video: VideoInfo) => {
		if (!currentVideo) {
			playVideo(video, false);
			showToast("Aggiunto alla coda");
		} else {
			queueRef.current = [...queueRef.current, video];
			setQueue(queueRef.current);
			showToast("Aggiunto alla coda");
		}
	});

	const removeFromQueue = useStableCallback((index: number) => {
		const newQueue = [...queueRef.current];
		newQueue.splice(index, 1);
		queueRef.current = newQueue;
		setQueue(newQueue);
	});

	const playVideo = useStableCallback(async (video: VideoInfo, autoplay: boolean = true) => {
		if (currentVideo && currentVideo.videoId !== video.videoId) {
			setHistory((prev) => [...prev, currentVideo]);
		}
		setIsLoading(true);
		setCurrentVideo(video);
		player.pause();

		try {
			// Yield the JS thread to allow the player to mount and animations to start
			// This prevents the heavy youtubei.js parsing from freezing the UI (e.g. blocking the BottomSheet from opening)
			await new Promise((resolve) => setTimeout(resolve, 50));

			const streamPromise = youtubeService.getAudioStream(video.videoId);

			const hq720 = `https://i.ytimg.com/vi/${video.videoId}/hq720.jpg`;
			const fallbackArtwork = `https://i.ytimg.com/vi/${video.videoId}/mqdefault.jpg`;
			const artworkPromise = fetch(hq720, { method: "HEAD" })
				.then((res) => (res.ok ? hq720 : fallbackArtwork))
				.catch(() => fallbackArtwork);

			const [streamInfo, bestArtwork] = await Promise.all([
				streamPromise,
				artworkPromise,
			]);

			autoplayPendingRef.current = autoplay;

			if (streamInfo && streamInfo.url) {
				await player.replaceAsync({
					uri: streamInfo.url,
					metadata: {
						title: video.title,
						artist: video.channelName || "YouTube Podcast",
						artwork: bestArtwork,
					},
				});

				const savedSpeed = await AsyncStorage.getItem("player_playback_rate");
				if (savedSpeed) {
					player.playbackRate = parseFloat(savedSpeed);
				}

				if (autoplay) {
					player.play(); // Fallback if readyToPlay was immediate
				}
				player.showNowPlayingNotification = true;
			} else {
				Alert.alert("Errore", "Nessun flusso compatibile trovato.");
				clearCurrentVideo();
			}
		} catch (e: any) {
			Alert.alert("Errore", e.message || "Impossibile riprodurre.");
			clearCurrentVideo();
		} finally {
			setIsLoading(false);
		}
	});

	const clearCurrentVideo = () => {
		setCurrentVideo(null);
		setExpanded(false);
	};

	const openVideo = useStableCallback((video: VideoInfo) => {
		setExpanded(true);
		if (currentVideo?.videoId !== video.videoId) playVideo(video);
	});

	const pause = useStableCallback(() => {
		player.pause();
	});

	const resume = useStableCallback(() => {
		player.play();
	});

	const seekTo = useStableCallback((time: number) => {
		player.currentTime = time;
	});

	const playPrevious = useStableCallback(async () => {
		if (player.currentTime > 3 || history.length === 0) {
			player.currentTime = 0;
			return;
		}
		const prev = history[history.length - 1];
		setHistory((prevHistory) => prevHistory.slice(0, -1));
		await playVideo(prev);
	});

	const actions = useMemo<PlayerActions>(
		() => ({
			player,
			playVideo,
			pause,
			resume,
			seekTo,
			addToQueue,
			removeFromQueue,
			playNext,
			playPrevious,
			setMaxQuality,
			setExpanded,
			openVideo,
		}),
		[player],
	);

	const state = useMemo<PlayerState>(
		() => ({ currentVideo, isLoading, queue, history, maxQuality }),
		[currentVideo, isLoading, queue, history, maxQuality],
	);

	return (
		<PlayerActionsContext.Provider value={actions}>
			<PlayerStateContext.Provider value={state}>
				<PlayerExpandedContext.Provider value={isExpanded}>
					{children}
					<ToastHUD
						visible={toastVisible}
						message={toastMessage}
						onHide={() => setToastVisible(false)}
					/>
				</PlayerExpandedContext.Provider>
			</PlayerStateContext.Provider>
		</PlayerActionsContext.Provider>
	);
}

export function usePlayerState() {
	const context = useContext(PlayerStateContext);
	if (!context) {
		throw new Error("usePlayerState must be used within a PlayerProvider");
	}
	return context;
}

export function usePlayerActions() {
	const context = useContext(PlayerActionsContext);
	if (!context) {
		throw new Error("usePlayerActions must be used within a PlayerProvider");
	}
	return context;
}

export function usePlayerExpanded() {
	return useContext(PlayerExpandedContext);
}
