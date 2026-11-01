import "./polyfill";

import Innertube from "youtubei.js";

export interface ChannelInfo {
	id: string;
	name: string;
	thumbnail: string;
	subscribers: string;
	description: string;
	category?: string;
}

export interface VideoInfo {
	videoId: string;
	title: string;
	duration: string;
	durationSeconds: number;
	viewCount: string;
	publishedDate: string;
	publishedTimestamp?: number;
	thumbnailUrl: string;
	channelName: string;
	channelId?: string;
}

interface VideoDetails {
	duration: string;
	durationSeconds: number;
	viewCount?: string;
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
		lower.includes("giorni") ||
		lower.match(/\bgg\b/)
	)
		return num * 86400;
	if (
		lower.includes("week") ||
		lower.includes("settimana") ||
		lower.includes("settimane") ||
		lower.includes("sett") ||
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

export function sortVideosByDate(videos: VideoInfo[]): VideoInfo[] {
	const now = Date.now();
	return [...videos].sort((a, b) => {
		const timeA = a.publishedTimestamp ?? (now - parseRelativeDate(a.publishedDate) * 1000);
		const timeB = b.publishedTimestamp ?? (now - parseRelativeDate(b.publishedDate) * 1000);
		return timeB - timeA;
	});
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

// "LIVE ALLE 21:00" if scheduled for today, otherwise "LIVE IL 25/09".
export function formatUpcomingLabel(start: Date): string {
	const pad = (n: number) => n.toString().padStart(2, "0");
	if (start.toDateString() === new Date().toDateString()) {
		return `LIVE ALLE ${pad(start.getHours())}:${pad(start.getMinutes())}`;
	}
	return `LIVE IL ${pad(start.getDate())}/${pad(start.getMonth() + 1)}`;
}

// LockupView metadata for scheduled streams: "Programmato per il giorno 25/09/26, 16:00".
function parseScheduledStart(video: any): Date | null {
	for (const row of video.metadata?.metadata?.metadata_rows ?? []) {
		for (const part of row.metadata_parts ?? []) {
			const text: string = part.text?.text ?? "";
			const m = text.match(/(\d{1,2})\/(\d{1,2})\/(\d{2,4}),?\s*(\d{1,2}):(\d{2})/);
			if (!m || !/programmat|scheduled/i.test(text)) continue;
			const year = m[3].length === 2 ? 2000 + +m[3] : +m[3];
			return new Date(year, +m[2] - 1, +m[1], +m[4], +m[5]);
		}
	}
	return null;
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
	private descriptionCache = new Map<string, string>();
	private detailsCache = new Map<string, VideoDetails>();

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



	async searchChannels(query: string): Promise<ChannelInfo[]> {
		await this.init();
		if (!this.yt) throw new Error("YouTube.js not initialized");

		const results = await this.yt.search(query, { type: "channel" });
		const channels = results.results ?? [];

		return channels
			.filter((ch: any) => ch.author?.name && ch.author.name.trim() !== "")
			.map((ch: any) => {
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

		// FORCED YIELD: Let the UI transition complete before freezing the JS thread
		// with heavy InnerTube parsing.
		await new Promise(resolve => setTimeout(resolve, 400));

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

		const scheduledStart = parseScheduledStart(video);
		if (scheduledStart) {
			duration = formatUpcomingLabel(scheduledStart);
			durationSeconds = 0;
		}

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

		let thumbnailUrl = `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
		if (video.content_image?.image?.length > 0) {
			thumbnailUrl = video.content_image.image[0].url;
		} else if (video.thumbnails?.length > 0) {
			thumbnailUrl = video.thumbnails[video.thumbnails.length - 1].url;
		}

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
			publishedTimestamp: scheduledStart?.getTime(),
		};
	}

	// Streams parsed, sorted VideoInfo[] one page at a time.
	// Each yielded array contains ALL videos seen so far, sorted by date,
	// so the UI can simply replace its state on each yield.
	async *streamChannelVideos(channelId: string, abortSignal?: () => boolean): AsyncGenerator<VideoInfo[]> {
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

		if (abortSignal?.()) return;

		// FORCED YIELD: Before falling back to the heavy InnerTube parser,
		// yield the JS thread for 300ms. This ensures any queued touch events
		// and screen transitions are executed instantly without freezing.
		await new Promise(resolve => setTimeout(resolve, 300));

		if (abortSignal?.()) return;

		if (abortSignal?.()) return;

		let controller = new AbortController();
		const yt = await Innertube.create({ 
			lang: "it", 
			location: "IT",
			fetch: async (input, init) => {
				if (abortSignal?.()) controller.abort();
				try {
					return await fetch(input, { ...init, signal: controller.signal });
				} catch (e) {
					throw e;
				}
			}
		});

		if (abortSignal?.()) return;
		
		let channel;
		try {
			channel = await yt.getChannel(channelId);
		} catch (e: any) {
			if (e.name === "AbortError") return;
			throw e;
		}

		if (abortSignal?.()) return;
		const channelName = channel.metadata?.title ?? "";

		const MAX_PAGES = 20;

		const processTab = async function* (firstPage: any) {
			let page = firstPage;
			let pageCount = 0;
			while (page && pageCount < MAX_PAGES) {
				if (abortSignal?.()) break;
				const raw: any[] = page.videos ?? [];
				yield raw;
				if (!page.has_continuation) break;
				try {
					// Yield before fetching continuation to avoid locking JS thread completely
					await new Promise(resolve => setTimeout(resolve, 50));
					if (abortSignal?.()) break;
					
					page = await page.getContinuation();
					pageCount++;
				} catch (e) {
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
				if (abortSignal?.()) return;
				for await (const rawPage of processTab(videosTab)) {
					if (abortSignal?.()) return;
					const newlyParsed = parsePage(rawPage);
					if (newlyParsed.length > 0) {
						const merged = [...accumulated, ...newlyParsed];
						const uniqueFeed = Array.from(new Map(merged.map(v => [v.videoId, v])).values());
						accumulated = sortVideosByDate(uniqueFeed);
						yield accumulated;
					}
				}
			} catch (e: any) {
				if (e.name === "AbortError") return;
				console.warn("Could not fetch videos tab", e);
			}
		}

		if (abortSignal?.()) return;

		if (channel.has_live_streams) {
			try {
				const liveTab = await channel.getLiveStreams();
				if (abortSignal?.()) return;
				for await (const rawPage of processTab(liveTab)) {
					if (abortSignal?.()) return;
					const newlyParsed = parsePage(rawPage);
					if (newlyParsed.length > 0) {
						const merged = [...accumulated, ...newlyParsed];
						const uniqueFeed = Array.from(new Map(merged.map(v => [v.videoId, v])).values());
						accumulated = sortVideosByDate(uniqueFeed);
						yield accumulated;
					}
				}
			} catch (e: any) {
				if (e.name === "AbortError") return;
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
	private async getRecentChannelVideosRss(channelId: string, filterRecent: boolean = false): Promise<VideoInfo[]> {
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
			const linkRegex = /<link rel="alternate" href="([^"]+)"/;
			const mediaGroupRegex = /<media:group>([\s\S]*?)<\/media:group>/;
			
			const videos: VideoInfo[] = [];
			
			for (const entry of entries) {
				const videoId = entry.match(videoIdRegex)?.[1];
				const published = entry.match(publishedRegex)?.[1];
				
				if (entry.match(linkRegex)?.[1]?.includes("/shorts/")) continue;

				if (videoId && published) {
					const date = new Date(published);
					const now = new Date();
					const diffSeconds = (now.getTime() - date.getTime()) / 1000;
					
					if (!filterRecent || diffSeconds <= ONE_WEEK_SECONDS) {
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
							publishedTimestamp: date.getTime(),
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

	// Used by Home screen to avoid blocking completely if RSS rate limits are hit.
	async getHomeFeedForChannel(channelId: string): Promise<VideoInfo[]> {
		try {
			return await this.getRecentChannelVideosRss(channelId, true);
		} catch (e) {
			console.warn("RSS loading failed for Home feed", e);
			return [];
		}
	}

	// Latest videos (RSS, no age filter) of several channels, merged and sorted by date.
	async getRecentVideos(channelIds: string[]): Promise<VideoInfo[]> {
		const results = await Promise.all(
			channelIds.map((id) => this.getRecentChannelVideosRss(id)),
		);
		return sortVideosByDate(results.flat());
	}

	async getVideoDescription(videoId: string): Promise<string> {
		const cached = this.descriptionCache.get(videoId);
		if (cached !== undefined) return cached;

		await this.init();
		const info = await this.yt!.getBasicInfo(videoId);
		const description = info.basic_info.short_description ?? "";
		this.descriptionCache.set(videoId, description);
		return description;
	}

	// Yields the feed progressively enriched with durations
	async *enrichVideoDetails(videos: VideoInfo[], abortSignal?: () => boolean, pauseSignal?: () => boolean): AsyncGenerator<VideoInfo[]> {
		await this.init();
		const yt = this.yt!;
		const updatedVideos = [...videos];

		const applyDetails = (videoId: string, details: VideoDetails) => {
			const index = updatedVideos.findIndex(vid => vid.videoId === videoId);
			if (index === -1) return;
			updatedVideos[index] = {
				...updatedVideos[index],
				duration: details.duration,
				durationSeconds: details.durationSeconds,
				viewCount: details.viewCount ?? updatedVideos[index].viewCount,
			};
		};

		const needsUpdate = (v: VideoInfo) => v.duration === "Play" || v.durationSeconds === 0;

		// Already-known videos are applied at once, without network requests.
		let appliedFromCache = false;
		for (const v of updatedVideos.filter(needsUpdate)) {
			const cached = this.detailsCache.get(v.videoId);
			if (cached) {
				applyDetails(v.videoId, cached);
				appliedFromCache = true;
			}
		}
		if (appliedFromCache) yield [...updatedVideos];

		const videosToUpdate = updatedVideos.filter(needsUpdate);

		for (let i = 0; i < videosToUpdate.length; i++) {
			if (abortSignal?.()) break;

			while (pauseSignal && pauseSignal()) {
				await new Promise(resolve => setTimeout(resolve, 500));
				if (abortSignal?.()) return;
			}

			const v = videosToUpdate[i];
			try {
				const info = await Promise.race([
					yt.getBasicInfo(v.videoId),
					new Promise<any>((_, reject) => setTimeout(() => reject(new Error("Timeout")), 10000))
				]);
				
				if (info && info.basic_info) {
					const durSecs = info.basic_info.duration || 0;
					const isLive = info.basic_info.is_live || info.basic_info.is_upcoming;
					
					let durText = v.duration;
					const start = info.basic_info.start_timestamp;
					if (info.basic_info.is_upcoming && start) {
						durText = formatUpcomingLabel(start);
					} else if (isLive) {
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

					const details: VideoDetails = {
						duration: durText,
						durationSeconds: durSecs,
						viewCount: info.basic_info.view_count
							? formatViewCount(info.basic_info.view_count.toString())
							: undefined,
					};
					applyDetails(v.videoId, details);
					// Live/scheduled labels change over time, so only regular videos are cached.
					if (!isLive && durSecs > 0) this.detailsCache.set(v.videoId, details);
				}
			} catch (e) {
				console.warn(`Failed to get basic info for ${v.videoId}`, e);
			}
			
			if (abortSignal?.()) break;
			yield [...updatedVideos];

			// FORCED YIELD: Prevent this background task from hogging the JS thread
			// We pause for 500ms between EACH video so the UI remains butter smooth.
			await new Promise(resolve => setTimeout(resolve, 500));
		}
	}

	// Clients tried in order. VISIONOS/IOS return an HLS manifest (adaptive, up to 4K,
	// native to AVPlayer); ANDROID only exposes a 360p progressive fallback.
	// ANDROID_VR/WEB are excluded: VR URLs now 403 without a PO token, WEB needs a
	// JS evaluator for deciphering.
	private static readonly STREAM_CLIENTS = ["VISIONOS", "IOS", "ANDROID", "MWEB"] as const;

	// Quick range request to make sure googlevideo actually serves the URL
	// before handing it to AVPlayer (which only reports a generic error).
	private async isStreamReachable(url: string, ranged = true): Promise<boolean> {
		try {
			const res = await fetch(url, ranged ? { headers: { Range: "bytes=0-0" } } : undefined);
			return res.ok;
		} catch {
			return false;
		}
	}

	private async pickStream(info: any): Promise<AudioStreamInfo | null> {
		const hls = info.streaming_data?.hls_manifest_url;
		if (hls && (await this.isStreamReachable(hls, false))) {
			return {
				url: hls,
				codec: "hls",
				mimeType: "application/x-mpegURL",
				bitrate: 0,
				sampleRate: 44100,
				channels: 2,
				contentLengthBytes: 0,
			};
		}

		const progressive = (info.streaming_data?.formats ?? [])
			.filter((f: any) => f.has_audio && f.has_video && f.url)
			.sort((a: any, b: any) => {
				const aH = a.height ?? 0;
				const bH = b.height ?? 0;
				if (aH <= 720 && bH > 720) return -1;
				if (bH <= 720 && aH > 720) return 1;
				return bH - aH;
			});

		for (const fmt of progressive) {
			if (!(await this.isStreamReachable(fmt.url))) continue;
			return {
				url: fmt.url,
				codec: "progressive",
				mimeType: fmt.mime_type,
				bitrate: fmt.bitrate ?? 0,
				sampleRate: fmt.audio_sample_rate ?? 0,
				channels: fmt.audio_channels ?? 2,
				contentLengthBytes: fmt.content_length ?? 0,
			};
		}

		return null;
	}

	async getAudioStream(videoId: string): Promise<AudioStreamInfo | null> {
		await this.init();
		const yt = this.yt!;
		let lastReason: string | undefined;

		for (const client of YouTubeService.STREAM_CLIENTS) {
			try {
				const info = await yt.getBasicInfo(videoId, { client });
				const status = info.playability_status?.status;
				if (status && status !== "OK") {
					lastReason = info.playability_status?.reason;
					if (status === "LIVE_STREAM_OFFLINE") break;
					continue;
				}

				const stream = await this.pickStream(info);
				if (stream) {
					console.log(`[YouTube] Stream ${stream.codec} via ${client}`);
					return stream;
				}
			} catch (e) {
				console.log(`[YouTube] Client ${client} fallito`, e);
			}
		}

		throw new Error(lastReason || "Nessun flusso audio/video compatibile trovato");
	}
}

export const youtubeService = new YouTubeService();
