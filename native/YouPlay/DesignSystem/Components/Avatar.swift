import SwiftUI

struct Avatar: View {
	let url: URL?
	var size = Metrics.avatar

	var body: some View {
		RemoteImage(url: url)
			.frame(width: size, height: size)
			.clipShape(.circle)
	}
}
