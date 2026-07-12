import "./polyfill";

import Innertube from "youtubei.js";

export interface ChannelInfo {
	id: string;
	name: string;
	thumbnail: string;
	subscribers: string;
	description: string;
}

export interface VideoInfo {
	videoId: string;
	title: string;
	duration: string;
	durationSeconds: number;
	viewCount: string;
	publishedDate: string;
	thumbnailUrl: string;
	channelName: string;
	channelId?: string;
}

export interface AudioStreamInfo {
	url: string;
	fallbackUrl?: string;
	codec: string;
	mimeType: string;
	bitrate: number;
	sampleRate: number;
	channels: number;
	contentLengthBytes: number;
}

export function parseRelativeDate(text: string): number {
	if (!text) return Infinity;
	const numMatch = text.match(/\d+/);
	if (!numMatch) return Infinity;
	const num = parseInt(numMatch[0], 10);

	const lower = text.toLowerCase();
	if (lower.includes("second") || lower.match(/\bsec\b/)) return num;
	if (
		lower.includes("minute") ||
		lower.includes("minuto") ||
		lower.includes("minuti") ||
		lower.match(/\bmin\b/)
	)
		return num * 60;
	if (
		lower.includes("hour") ||
		lower.match(/\bora\b/) ||
		lower.match(/\bore\b/) ||
		lower.match(/\bhr\b/)
	)
		return num * 3600;
	if (
		lower.includes("day") ||
		lower.includes("giorno") ||
		lower.includes("giorni")
	)
		return num * 86400;
	if (
		lower.includes("week") ||
		lower.includes("settimana") ||
		lower.includes("settimane") ||
		lower.match(/\bwk\b/)
	)
		return num * 86400 * 7;
	if (
		lower.includes("month") ||
		lower.includes("mese") ||
		lower.includes("mesi") ||
		lower.match(/\bmo\b/)
	)
		return num * 86400 * 30;
	if (
		lower.includes("year") ||
		lower.includes("anno") ||
		lower.includes("anni") ||
		lower.match(/\byr\b/)
	)
		return num * 86400 * 365;
	return Infinity;
}

export function formatISODateToRelative(isoString: string): string {
	const published = new Date(isoString);
	const now = new Date();
	const diffMs = now.getTime() - published.getTime();
	const seconds = Math.floor(diffMs / 1000);

	if (seconds < 60) return `${seconds} secondi fa`;
	const m = Math.floor(seconds / 60);
	if (m < 60) return `${m} minut${m === 1 ? 'o' : 'i'} fa`;
	const h = Math.floor(seconds / 3600);
	if (h < 24) return `${h} or${h === 1 ? 'a' : 'e'} fa`;
	const d = Math.floor(seconds / 86400);
	if (d < 7) return `${d} giorn${d === 1 ? 'o' : 'i'} fa`;
	const w = Math.floor(seconds / (86400 * 7));
	if (w < 4) return `${w} settiman${w === 1 ? 'a' : 'e'} fa`;
	const mo = Math.floor(seconds / (86400 * 30));
	if (mo < 12) return `${mo} mes${mo === 1 ? 'e' : 'i'} fa`;
	const y = Math.floor(seconds / (86400 * 365));
	return `${y} ann${y === 1 ? 'o' : 'i'} fa`;
}

export function formatViewCount(viewsStr: string): string {
	const views = parseInt(viewsStr, 10);
	if (isNaN(views)) return `${viewsStr} visualizzazioni`;

	if (views < 1000) {
		return `${views} visualizzazioni`;
	} else if (views < 1000000) {
		const k = views / 1000;
		const formatted = k >= 10 ? Math.floor(k).toString() : k.toFixed(1).replace('.', ',');
		return `${formatted.replace(',0', '')}K visualizzazioni`;
	} else {
		const mln = views / 1000000;
		const formatted = mln >= 10 ? Math.floor(mln).toString() : mln.toFixed(1).replace('.', ',');
		return `${formatted.replace(',0', '')} Mln visualizzazioni`;
	}
}

class YouTubeService {
	private yt: Innertube | null = null;
	private initializing: Promise<void> | null = null;

	// Shared client for lightweight metadata requests (search, channel info)
	async init() {
		if (this.yt) return;
		if (this.initializing) return this.initializing;

		this.initializing = (async () => {
			this.yt = await Innertube.create({ lang: "it", location: "IT" });
		})();

		await this.initializing;
		this.initializing = null;
	}

	// Always returns a fresh Innertube instance to avoid stale YouTube session
	// caching which causes old videos and expired stream URLs.
	private async freshClient(): Promise<Innertube> {
		return Innertube.create({ lang: "it", location: "IT" });
	}

	async searchChannels(query: string): Promise<ChannelInfo[]> {
		await this.init();
		if (!this.yt) throw new Error("YouTube.js not initialized");

		const results = await this.yt.search(query, { type: "channel" });
		const channels = results.results ?? [];

		return channels.map((ch: any) => {
			const thumbnails = ch.author?.thumbnails ?? [];
			let thumbUrl =
				thumbnails.length > 0 ? thumbnails[thumbnails.length - 1].url : "";
			if (thumbUrl.startsWith("//")) thumbUrl = "https:" + thumbUrl;
			return {
				id: ch.author?.id ?? "",
				name: ch.author?.name ?? "Sconosciuto",
				thumbnail: thumbUrl,
				subscribers: ch.subscriber_count?.text ?? "",
				description: ch.description_snippet?.text ?? "",
			};
		});
	}

	async getChannelInfo(id: string): Promise<ChannelInfo> {
		await this.init();
		if (!this.yt) throw new Error("YouTube.js not initialized");

		const channel = await this.yt.getChannel(id);
		const thumbnails = channel.metadata?.avatar ?? [];
		let thumbUrl =
			thumbnails.length > 0 ? thumbnails[thumbnails.length - 1].url : "";
		if (thumbUrl.startsWith("//")) thumbUrl = "https:" + thumbUrl;

		let subscribers = (channel.header as any)?.subscribers?.text ?? "";
		const metadataRows =
			(channel.header as any)?.content?.metadata?.metadata_rows ?? [];
		for (const row of metadataRows) {
			for (const part of row.metadata_parts ?? []) {
				const text =
					part.text?.text ?? (typeof part.text === "string" ? part.text : "");
				if (
					text.toLowerCase().includes("subscriber") ||
					text.toLowerCase().includes("iscritti")
				) {
					subscribers = text;
				}
			}
		}

		return {
			id: channel.metadata?.external_id ?? id,
			name: channel.metadata?.title ?? "Sconosciuto",
			thumbnail: thumbUrl,
			subscribers,
			description: channel.metadata?.description ?? "",
		};
	}

	// Parses a raw video object from youtubei.js into a VideoInfo.
	// Returns null if the video should be skipped (live, members-only, no duration).
	private parseRawVideo(
		video: any,
		channelId: string,
		channelName: string,
	): VideoInfo | null {
		if (video.is_live) return null;

		const badges = video.badges ?? video.author?.badges ?? [];
		for (const badge of badges) {
			const text = badge.text?.toLowerCase() || "";
			if (
				text.includes("member") ||
				text.includes("abbonat") ||
				text.includes("sponsor")
			) {
				return null;
			}
		}

		const title =
			video.metadata?.title?.text ?? video.title?.text ?? "Senza titolo";
		const videoId = video.content_id ?? video.video_id ?? video.id ?? "";

		let duration = "";
		let durationSeconds = 0;
		for (const overlay of video.content_image?.overlays ?? []) {
			if (overlay.type === "ThumbnailBottomOverlayView") {
				for (const badge of overlay.badges ?? []) {
					if (badge.text) {
						duration = badge.text;
						break;
					}
				}
			}
			if (duration) break;
		}

		// Fallback for LockupView
		if (!duration) {
			for (const overlay of video.thumbnail_overlays ?? []) {
				if (overlay.type === "ThumbnailOverlayTimeStatusView" || overlay.type === "ThumbnailOverlayTimeStatus") {
					duration = overlay.text?.toString() || overlay.text || "";
					break;
				}
			}
		}

		if (duration) {
			const parts = duration.split(":").map(Number);
			if (parts.length === 3)
				durationSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
			else if (parts.length === 2)
				durationSeconds = parts[0] * 60 + parts[1];
		}

		if (!videoId || !duration) return null;

		let viewCount = "";
		let publishedDate = "";
		for (const row of video.metadata?.metadata?.metadata_rows ?? []) {
			for (const part of row.metadata_parts ?? []) {
				const text =
					part.text?.text ?? (typeof part.text === "string" ? part.text : "");
				if (text.includes("view") || text.includes("visualizzazion")) {
					viewCount = text;
				} else if (
					text.includes("ago") ||
					text.includes("fa") ||
					text.includes("hour") ||
					text.includes("day") ||
					text.includes("week") ||
					text.includes("month") ||
					text.includes("year") ||
					text.includes("Streamed") ||
					text.includes("Trasmesso")
				) {
					publishedDate = text
						.replace(/Trasmesso in streaming /i, "")
						.replace(/Streamed /i, "")
						.trim();
				}
			}
		}

		const thumbImages = video.content_image?.image ?? [];
		const thumbnailUrl =
			Array.isArray(thumbImages) && thumbImages.length > 0
				? thumbImages[0].url
				: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;

		return {
			title,
			videoId,
			duration,
			durationSeconds,
			viewCount,
			publishedDate,
			thumbnailUrl,
			channelName,
			channelId,
		};
	}

	private sortByDate(videos: VideoInfo[]): VideoInfo[] {
		return [...videos].sort((a, b) => {
			const dateA = parseRelativeDate(a.publishedDate);
			const dateB = parseRelativeDate(b.publishedDate);
			if (dateA === dateB) return 0;
			if (dateA === Infinity) return 1;
			if (dateB === Infinity) return -1;
			return dateA - dateB;
		});
	}

	// Streams parsed, sorted VideoInfo[] one page at a time.
	// Each yielded array contains ALL videos seen so far, sorted by date,
	// so the UI can simply replace its state on each yield.
	async *streamChannelVideos(channelId: string): AsyncGenerator<VideoInfo[]> {
		let accumulated: VideoInfo[] = [];

		// Yield RSS feed instantly for blazing fast initial load
		try {
			const rssVideos = await this.getRecentChannelVideosRss(channelId);
			if (rssVideos.length > 0) {
				accumulated = rssVideos;
				yield accumulated;
			}
		} catch (e) {
			console.error("Failed to fetch RSS as preview", e);
		}

		const yt = await this.freshClient();
		const channel = await yt.getChannel(channelId);
		const channelName = channel.metadata?.title ?? "";

		const MAX_PAGES = 20;

		const processTab = async function* (firstPage: any) {
			let page = firstPage;
			let pageCount = 0;
			while (page && pageCount < MAX_PAGES) {
				const raw: any[] = page.videos ?? [];
				yield raw;
				if (!page.has_continuation) break;
				try {
					page = await page.getContinuation();
					pageCount++;
				} catch {
					break;
				}
			}
		};

		const parsePage = (rawVideos: any[]): VideoInfo[] =>
			rawVideos
				.map((v: any) => this.parseRawVideo(v, channelId, channelName))
				.filter((v): v is VideoInfo => v !== null);

		if (channel.has_videos) {
			try {
				const videosTab = await channel.getVideos();
				for await (const rawPage of processTab(videosTab)) {
					const newlyParsed = parsePage(rawPage);
					if (newlyParsed.length > 0) {
						const merged = [...accumulated, ...newlyParsed];
						const uniqueFeed = Array.from(new Map(merged.map(v => [v.videoId, v])).values());
						accumulated = this.sortByDate(uniqueFeed);
						yield accumulated;
					}
				}
			} catch (e) {
				console.warn("Could not fetch videos tab", e);
			}
		}

		if (channel.has_live_streams) {
			try {
				const liveTab = await channel.getLiveStreams();
				for await (const rawPage of processTab(liveTab)) {
					const newlyParsed = parsePage(rawPage);
					if (newlyParsed.length > 0) {
						const merged = [...accumulated, ...newlyParsed];
						const uniqueFeed = Array.from(new Map(merged.map(v => [v.videoId, v])).values());
						accumulated = this.sortByDate(uniqueFeed);
						yield accumulated;
					}
				}
			} catch (e) {
				console.warn("Could not fetch live streams tab", e);
			}
		}
	}

	// Backward-compatible: fetches everything and returns a single sorted array.
	async getChannelVideos(channelId: string): Promise<VideoInfo[]> {
		let result: VideoInfo[] = [];
		for await (const page of this.streamChannelVideos(channelId)) {
			result = page;
		}
		return result;
	}

	// Fetches videos up to one week old using RSS (EXTREMELY FAST).
	async getRecentChannelVideosRss(channelId: string): Promise<VideoInfo[]> {
		const ONE_WEEK_SECONDS = 7 * 86400;
		try {
			const res = await fetch(
				`https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}&_=${Date.now()}`,
				{
					headers: {
						"Cache-Control": "no-cache",
						Pragma: "no-cache",
					},
				}
			);
			if (!res.ok) throw new Error("RSS fetch failed");
			const text = await res.text();
			
			const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
			const entries = text.match(entryRegex) || [];
			
			const titleRegex = /<title>([\s\S]*?)<\/title>/;
			const videoIdRegex = /<yt:videoId>([^<]+)<\/yt:videoId>/;
			const channelIdRegex = /<yt:channelId>([^<]+)<\/yt:channelId>/;
			const channelNameRegex = /<author>\s*<name>([^<]+)<\/name>/;
			const publishedRegex = /<published>([^<]+)<\/published>/;
			const mediaGroupRegex = /<media:group>([\s\S]*?)<\/media:group>/;
			
			const videos: VideoInfo[] = [];
			
			for (const entry of entries) {
				const videoId = entry.match(videoIdRegex)?.[1];
				const published = entry.match(publishedRegex)?.[1];
				
				if (videoId && published) {
					const date = new Date(published);
					const now = new Date();
					const diffSeconds = (now.getTime() - date.getTime()) / 1000;
					
					if (diffSeconds <= ONE_WEEK_SECONDS) {
						const titleMatch = entry.match(titleRegex);
						const title = titleMatch ? titleMatch[1].replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>') : "Senza titolo";
						const chId = entry.match(channelIdRegex)?.[1] || channelId;
						const channelName = entry.match(channelNameRegex)?.[1] || "";
						
						const mediaGroup = entry.match(mediaGroupRegex)?.[1] || "";
						const thumbnail = mediaGroup.match(/<media:thumbnail url="([^"]+)"/)?.[1];
						const views = mediaGroup.match(/<media:statistics views="([^"]+)"/)?.[1];
						
						videos.push({
							videoId,
							title,
							publishedDate: formatISODateToRelative(published),
							thumbnailUrl: thumbnail || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
							channelId: chId,
							channelName,
							viewCount: views ? formatViewCount(views) : "",
							duration: "Play",
							durationSeconds: 0,
						});
					}
				}
			}
			
			return videos;
		} catch (e) {
			console.warn("RSS loading failed, using fallback", e);
			return [];
		}
	}

	// Yields the feed progressively enriched with durations
	async *enrichVideoDetails(videos: VideoInfo[], abortSignal?: () => boolean): AsyncGenerator<VideoInfo[]> {
		const yt = await this.freshClient();
		const updatedVideos = [...videos];

		const videosToUpdate = updatedVideos.filter(v => v.duration === "Play" || v.durationSeconds === 0);

		const CHUNK_SIZE = 3;
		for (let i = 0; i < videosToUpdate.length; i += CHUNK_SIZE) {
			if (abortSignal?.()) break;

			const chunk = videosToUpdate.slice(i, i + CHUNK_SIZE);
			const chunkPromises = chunk.map(async (v) => {
				try {
					const info = await Promise.race([
						yt.getBasicInfo(v.videoId),
						new Promise<any>((_, reject) => setTimeout(() => reject(new Error("Timeout")), 10000))
					]);
					
					if (info && info.basic_info) {
						const durSecs = info.basic_info.duration || 0;
						
						let durText = v.duration;
						if (info.basic_info.is_live || info.basic_info.is_upcoming) {
							durText = "DAL VIVO";
						} else if (durSecs > 0) {
							const h = Math.floor(durSecs / 3600);
							const m = Math.floor((durSecs % 3600) / 60);
							const s = durSecs % 60;
							if (h > 0) {
								durText = `${h}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
							} else {
								durText = `${m}:${s.toString().padStart(2, "0")}`;
							}
						}

						const index = updatedVideos.findIndex(vid => vid.videoId === v.videoId);
						if (index !== -1) {
							updatedVideos[index] = {
								...updatedVideos[index],
								duration: durText,
								durationSeconds: durSecs,
								viewCount: info.basic_info.view_count 
									? formatViewCount(info.basic_info.view_count.toString()) 
									: updatedVideos[index].viewCount
							};
						}
					}
				} catch (e) {
					console.warn(`Failed to get basic info for ${v.videoId}`, e);
				}
			});
			
			await Promise.all(chunkPromises);
			
			if (abortSignal?.()) break;
			yield [...updatedVideos];
		}
	}

	async getAudioStream(videoId: string): Promise<AudioStreamInfo | null> {
		// Use a fresh client: stream URLs from YouTube expire quickly and a cached
		// Innertube session may return already-expired signed URLs.
		const yt = await this.freshClient();

		try {
			const info = await yt.getBasicInfo(videoId, {
				client: "ANDROID_VR",
			});

			if (info.playability_status?.status === "UNPLAYABLE") {
				throw new Error(
					info.playability_status.reason ||
						"Video non riproducibile (forse riservato agli abbonati)",
				);
			}
			if (info.playability_status?.status === "LIVE_STREAM_OFFLINE") {
				throw new Error(
					info.playability_status.reason ||
						"Questo evento dal vivo non è ancora iniziato.",
				);
			}

			const progressive = (info.streaming_data?.formats ?? []).filter(
				(f: any) => f.has_audio && f.url,
			);

			// Ritorna direttamente il formato progressive (MP4 con audio + video)
			if (progressive.length > 0) {
				// Cerca il formato a qualità più bassa/accettabile per non consumare troppa banda
				const fmt = progressive.sort((a: any, b: any) => (a.height ?? 0) - (b.height ?? 0))[0];
				return {
					url: fmt.url ?? "",
					codec: "progressive",
					mimeType: fmt.mime_type,
					bitrate: fmt.bitrate ?? 0,
					sampleRate: fmt.audio_sample_rate ?? 0,
					channels: fmt.audio_channels ?? 2,
					contentLengthBytes: fmt.content_length ?? 0,
				};
			}

			// Fallback: HLS manifest
			if (info.streaming_data?.hls_manifest_url) {
				return {
					url: info.streaming_data.hls_manifest_url,
					codec: "hls",
					mimeType: "application/x-mpegURL",
					bitrate: 0,
					sampleRate: 44100,
					channels: 2,
					contentLengthBytes: 0,
				};
			}

			throw new Error("Nessun flusso audio compatibile trovato");
		} catch (e: any) {
			throw e;
		}
	}
}

export const youtubeService = new YouTubeService();
