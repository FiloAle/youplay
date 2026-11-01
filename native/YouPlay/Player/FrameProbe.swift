import QuartzCore
import os

/// Measures dropped frames during player transitions. Read with:
/// `xcrun simctl spawn booted log stream --predicate 'subsystem == "com.filippoaleee.youplay.native"'`
@MainActor
final class FrameProbe: NSObject {
	static let shared = FrameProbe()

	private let logger = Logger(subsystem: "com.filippoaleee.youplay.native", category: "frames")
	private var link: CADisplayLink?
	private var label = ""
	private var last: CFTimeInterval = 0
	private var frames = 0
	private var dropped = 0
	private var worst: CFTimeInterval = 0

	func start(_ label: String) {
		#if DEBUG
		report()
		self.label = label
		let link = CADisplayLink(target: self, selector: #selector(tick))
		link.add(to: .main, forMode: .common)
		self.link = link
		#endif
	}

	func stop() {
		report()
	}

	private func report() {
		guard link != nil else { return }
		link?.invalidate()
		link = nil
		let worstMs = String(format: "%.1f", worst * 1000)
		logger.notice("[FRAMES] \(self.label, privacy: .public) frames=\(self.frames) dropped=\(self.dropped) worstMs=\(worstMs, privacy: .public)")
		last = 0
		frames = 0
		dropped = 0
		worst = 0
	}

	@objc private func tick(_ link: CADisplayLink) {
		if last > 0 {
			let delta = link.timestamp - last
			frames += 1
			worst = max(worst, delta)
			if delta > (link.targetTimestamp - link.timestamp) * 1.5 { dropped += 1 }
		}
		last = link.timestamp
	}
}
