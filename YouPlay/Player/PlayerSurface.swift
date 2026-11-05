import AVFoundation
import SwiftUI

/// The page's slot for the video. It keeps one size for its whole life: the player only ever scales it.
/// The video itself belongs to `VideoStage`, which lends it to full screen and takes it back.
struct PlayerSurface: UIViewRepresentable {
	let stage: VideoStage
	let isExpanded: Bool

	func makeUIView(context: Context) -> UIView {
		let container = UIView()
		container.backgroundColor = UIColor(Palette.videoBackground)
		container.clipsToBounds = true
		stage.attach(to: container)
		return container
	}

	func updateUIView(_ container: UIView, context: Context) {
		stage.attach(to: container)
		stage.setInlineGravity(isExpanded ? .resizeAspect : .resizeAspectFill)
	}
}
