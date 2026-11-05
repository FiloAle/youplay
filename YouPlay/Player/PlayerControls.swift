import AVKit
import SwiftUI

/// The video's controls, on the page and in full screen. A tap shows or hides them, and while the video
/// plays they hide on their own. On the page, a thin progress line stays at the bottom of the video.
struct PlayerControls: View {
	let isFullScreen: Bool

	@Environment(PlayerModel.self) private var player
	@State private var isVisible = true
	/// Where the finger has the progress bar, as a fraction of the video, until the seek gets there:
	/// the clock would pull the thumb and the time back meanwhile.
	@State private var scrubPosition: Double?
	/// Changes on every touch of a control, which restarts the timeout.
	@State private var touches = 0
	@State private var isShowingQueue = false
	@State private var skipFeedback: SkipFeedback?
	@State private var width: CGFloat = 0

	private static let skipInterval = 10.0

	var body: some View {
		ZStack {
			// The whole video, edges included: only the controls keep clear of the notch and the home indicator.
			if isVisible {
				Palette.videoScrim
					.ignoresSafeArea()
					.transition(.opacity)
			}
			Color.clear
				.contentShape(.rect)
				.ignoresSafeArea()
				.onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
				// Declared first, so that a double tap skips without also showing or hiding the controls.
				.onTapGesture(count: 2) { location in skip(towards: location) }
				.onTapGesture { isVisible.toggle() }
			SkipFeedbackOverlay(feedback: skipFeedback)
			// Hidden rather than removed: removing it would close the settings menu if it's open.
			transport
				.opacity(isVisible ? 1 : 0)
				.allowsHitTesting(isVisible)
			controls
				.padding(.horizontal, isFullScreen ? Spacing.lg : Spacing.xs)
				.padding(.top, Spacing.xs)
				// On the page, clear of the progress bar on the video's edge.
				.padding(.bottom, isFullScreen ? Spacing.xs : Spacing.md)
				.opacity(isVisible ? 1 : 0)
				.allowsHitTesting(isVisible)
			if !isFullScreen {
				// The line rests on the video's bottom edge, inside it. The touch area reaches a little below.
				ProgressScrubber(isActive: isVisible, position: $scrubPosition)
					.frame(maxHeight: .infinity, alignment: .bottom)
					.offset(y: (Metrics.minimumTouchTarget - Metrics.progressTrack) / 2)
			}
		}
		.animation(Motion.standard, value: isVisible)
		.animation(Motion.standard, value: skipFeedback)
		.task(id: skipFeedback?.id) {
			guard skipFeedback != nil else { return }
			try? await Task.sleep(for: Motion.skipFeedbackDuration)
			if !Task.isCancelled { skipFeedback = nil }
		}
		// Presented from the controls, so that it also opens on top of full screen.
		.sheet(isPresented: $isShowingQueue) { QueueSheet() }
		// The page's controls are under the video while it flies in and out of full screen, and would pop out
		// when it lands back. Hidden as it leaves, they stay out of the way until a tap brings them back.
		.onChange(of: player.stage.isFullScreen) { _, isFullScreen in
			if isFullScreen, !self.isFullScreen { isVisible = false }
		}
		.task(id: Timeout(isVisible: isVisible, isPlaying: player.isPlaying && !player.isWaiting, isScrubbing: scrubPosition != nil, touches: touches)) {
			// The spinner stays in sight until the video actually plays.
			guard isVisible, player.isPlaying, !player.isWaiting, scrubPosition == nil else { return }
			try? await Task.sleep(for: Motion.controlsTimeout)
			if !Task.isCancelled { isVisible = false }
		}
	}

	/// In the middle of the whole video, apart from the rows at its edges: in full screen those keep clear
	/// of the home indicator, which is only at the bottom, and the bottom one also holds the progress bar.
	private var transport: some View {
		HStack(spacing: Spacing.xl) {
			control("gobackward.10", label: "Indietro di 10 secondi", emphasis: .secondary) { player.skip(by: -Self.skipInterval) }
				.disabled(!player.canSkip(by: -Self.skipInterval))
			playbackControl
			control("goforward.10", label: "Avanti di 10 secondi", emphasis: .secondary) { player.skip(by: Self.skipInterval) }
				.disabled(!player.canSkip(by: Self.skipInterval))
		}
		.controlSize(isFullScreen ? .large : .regular)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea()
	}

	private var controls: some View {
		VStack(spacing: 0) {
			HStack(spacing: 0) {
				control("list.bullet", label: "Coda") { isShowingQueue = true }
				if isFullScreen, let title = player.current?.title {
					Text(title)
						.font(Typography.rowTitle)
						.foregroundStyle(Palette.badgeText)
						.lineLimit(1)
						.padding(.horizontal, Spacing.sm)
				}
				Spacer(minLength: 0)
				VideoSettingsMenu()
			}
			Spacer(minLength: 0)
			HStack(spacing: 0) {
				PlaybackTime(scrubPosition: scrubPosition)
					.padding(.leading, Spacing.sm)
				Spacer(minLength: 0)
				control(
					isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
					label: isFullScreen ? "Esci da schermo intero" : "Schermo intero",
					action: toggleFullScreen
				)
			}
			// Above the bar's touch area, which reaches up into this row.
			.zIndex(1)
			if isFullScreen {
				ProgressScrubber(isActive: true, position: $scrubPosition)
					.padding(.horizontal, Spacing.sm)
					// Its touch area is taller than the line, which would otherwise sit far below the row.
					.padding(.top, -Spacing.md)
			}
		}
	}

	@ViewBuilder
	private var playbackControl: some View {
		if player.isWaiting {
			VideoControlCircle(emphasis: .primary) {
				ProgressView()
					.tint(Palette.badgeText)
			}
		} else {
			control(
				player.isPlaying ? "pause.fill" : "play.fill",
				label: player.isPlaying ? "Pausa" : "Riproduci",
				emphasis: .primary,
				action: player.togglePlayback
			)
		}
	}

	private func control(
		_ systemName: String,
		label: String,
		emphasis: VideoControlEmphasis = .standard,
		action: @escaping () -> Void
	) -> some View {
		VideoControlButton(systemName: systemName, label: label, emphasis: emphasis) {
			touches += 1
			action()
		}
	}

	/// The right half of the video skips forward, the left half back. Taps in a row add up, like "+30".
	private func skip(towards location: CGPoint) {
		let isForward = location.x > width / 2
		let seconds = isForward ? Self.skipInterval : -Self.skipInterval
		guard player.canSkip(by: seconds) else { return }
		player.skip(by: seconds)
		let previous = skipFeedback?.isForward == isForward ? skipFeedback?.seconds ?? 0 : 0
		skipFeedback = SkipFeedback(isForward: isForward, seconds: previous + Int(Self.skipInterval))
	}

	private func toggleFullScreen() {
		if isFullScreen {
			player.stage.exitFullScreen()
		} else {
			player.stage.enterFullScreen(controls: PlayerControls(isFullScreen: true).environment(player).tint(Palette.accent))
		}
	}
}

private struct SkipFeedback: Equatable {
	let isForward: Bool
	let seconds: Int
	/// New for every tap, so that each one keeps the label up a little longer.
	let id = UUID()
}

/// "+10" or "-10" in the half of the video that was double tapped.
private struct SkipFeedbackOverlay: View {
	let feedback: SkipFeedback?

	var body: some View {
		HStack(spacing: 0) {
			slot(isForward: false)
			slot(isForward: true)
		}
		.ignoresSafeArea()
		.allowsHitTesting(false)
	}

	private func slot(isForward: Bool) -> some View {
		ZStack {
			if let feedback, feedback.isForward == isForward {
				Text(isForward ? "+\(feedback.seconds)" : "-\(feedback.seconds)")
					.font(Typography.skipFeedback)
					.foregroundStyle(Palette.badgeText)
					.padding(.horizontal, Spacing.lg)
					.padding(.vertical, Spacing.sm)
					.glassEffect(.regular, in: .capsule)
					.transition(.opacity.combined(with: .scale(scale: 0.8)))
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

private struct Timeout: Hashable {
	let isVisible: Bool
	let isPlaying: Bool
	let isScrubbing: Bool
	let touches: Int
}

/// "0:05 - 0:48", or the live badge for a stream that has no end.
private struct PlaybackTime: View {
	let scrubPosition: Double?

	@Environment(PlayerModel.self) private var player

	var body: some View {
		let clock = player.clock
		if clock.isLive {
			VideoBadge(text: VideoBadge.liveText, isLive: true)
		} else if clock.duration > 0 {
			Text("\(Format.duration(seconds: Int(scrubPosition.map { $0 * clock.duration } ?? clock.currentTime))) - \(Format.duration(seconds: Int(clock.duration)))")
				.font(Typography.badge)
				.foregroundStyle(Palette.badgeText)
				.padding(.horizontal, Spacing.md)
				.frame(height: Metrics.videoControl)
				.glassEffect(.regular, in: .capsule)
		}
	}
}

/// A thin line while the video plays, with a thumb to drag while the controls are up.
private struct ProgressScrubber: View {
	let isActive: Bool
	@Binding var position: Double?

	@Environment(PlayerModel.self) private var player
	@State private var isDragging = false

	var body: some View {
		let clock = player.clock
		if !clock.isLive, clock.duration > 0 {
			GeometryReader { proxy in
				let width = proxy.size.width
				let fraction = position ?? min(1, clock.currentTime / clock.duration)
				let thumb = isDragging ? Metrics.progressThumb * 1.3 : Metrics.progressThumb
				ZStack(alignment: .leading) {
					Capsule()
						.fill(Palette.progressTrack)
						.frame(height: Metrics.progressTrack)
					Capsule()
						.fill(Palette.accent)
						.frame(width: width * fraction, height: Metrics.progressTrack)
					Circle()
						.fill(Palette.accent)
						.frame(width: thumb, height: thumb)
						// Scaled before it's moved, so it grows where it is and not from the bar's start.
						.scaleEffect(isActive ? 1 : 0)
						.offset(x: width * fraction - thumb / 2)
				}
				.frame(maxHeight: .infinity)
				.contentShape(.rect)
				.gesture(drag(width: width, duration: clock.duration))
			}
			.frame(height: Metrics.minimumTouchTarget)
			.allowsHitTesting(isActive)
			.animation(Motion.standard, value: isActive)
			.animation(Motion.standard, value: isDragging)
		}
	}

	private func drag(width: CGFloat, duration: Double) -> some Gesture {
		// Only a drag moves it: a stray tap near the video's edge mustn't jump through the video.
		DragGesture(minimumDistance: Metrics.scrubMinimumDistance)
			.onChanged { value in
				isDragging = true
				position = min(1, max(0, value.location.x / max(width, 1)))
			}
			.onEnded { _ in
				isDragging = false
				guard let position else { return }
				Task {
					await player.seek(to: position * duration)
					self.position = nil
				}
			}
	}
}

/// Speed, audio, subtitles, quality, AirPlay and Picture in Picture.
private struct VideoSettingsMenu: View {
	@Environment(PlayerModel.self) private var player
	@State private var airPlay = AirPlayTrigger()

	private static let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]

	private static let qualities = [
		(height: 0, label: "Automatica"),
		(height: 1080, label: "1080p"),
		(height: 720, label: "720p"),
		(height: 480, label: "480p"),
		(height: 360, label: "360p"),
	]

	var body: some View {
		Menu {
			Picker("Velocità", systemImage: "gauge.with.dots.needle.67percent", selection: Binding(get: { player.playbackRate }, set: player.setRate)) {
				ForEach(Self.speeds, id: \.self) { Text(Self.label(for: $0)).tag($0) }
			}
			.pickerStyle(.menu)

			if player.audioTracks.count > 1 {
				Picker("Audio", systemImage: "waveform", selection: Binding(get: { player.selectedAudio ?? "" }, set: player.selectAudio)) {
					ForEach(player.audioTracks, id: \.self) { Text($0).tag($0) }
				}
				.pickerStyle(.menu)
			}

			if !player.subtitleTracks.isEmpty {
				Picker("Sottotitoli", systemImage: "captions.bubble", selection: Binding(get: { player.selectedSubtitles }, set: player.selectSubtitles)) {
					Text("Disattivati").tag(String?.none)
					ForEach(player.subtitleTracks, id: \.self) { Text($0).tag(Optional($0)) }
				}
				.pickerStyle(.menu)
			}

			Picker("Qualità", systemImage: "slider.horizontal.3", selection: Binding(get: { player.maxQuality }, set: player.setMaxQuality)) {
				ForEach(Self.qualities, id: \.height) { Text($0.label).tag($0.height) }
			}
			.pickerStyle(.menu)

			Section {
				Button("Trasmetti", systemImage: "airplay.video", action: airPlay.show)
				if player.stage.supportsPictureInPicture {
					Button("Picture in Picture", systemImage: "pip.enter", action: player.stage.startPictureInPicture)
				}
			}
		} label: {
			VideoControlCircle {
				Image(systemName: "ellipsis")
					.font(Typography.videoControl)
					.foregroundStyle(Palette.badgeText)
			}
			.accessibilityLabel("Opzioni video")
		}
		// The system picker shows its list from here.
		.background { RoutePicker(trigger: airPlay) }
	}

	private static func label(for speed: Float) -> String {
		speed == 1 ? "Normale" : "\(speed.formatted(.number.locale(Locale(identifier: "it_IT"))))×"
	}
}

/// iOS shows the AirPlay list only from its own button, so a hidden one gets the tap from the menu.
@MainActor
private final class AirPlayTrigger {
	weak var picker: AVRoutePickerView?

	func show() {
		picker?.firstButton?.sendActions(for: .touchUpInside)
	}
}

private struct RoutePicker: UIViewRepresentable {
	let trigger: AirPlayTrigger

	func makeUIView(context: Context) -> AVRoutePickerView {
		let picker = AVRoutePickerView()
		picker.prioritizesVideoDevices = true
		picker.alpha = 0
		picker.isUserInteractionEnabled = false
		trigger.picker = picker
		return picker
	}

	func updateUIView(_ picker: AVRoutePickerView, context: Context) {
		trigger.picker = picker
	}
}

private extension UIView {
	var firstButton: UIButton? {
		self as? UIButton ?? subviews.lazy.compactMap(\.firstButton).first
	}
}
