import ImageIO
import SwiftUI

/// Downloads images once and keeps them decoded and downsampled, so lists scroll without flashes.
/// `NSCache` is thread-safe, which makes this safe to share.
final class ImageLoader: @unchecked Sendable {
	static let shared = ImageLoader()

	private static let maxPixelSize = 512

	private let cache: NSCache<NSURL, UIImage> = {
		let cache = NSCache<NSURL, UIImage>()
		cache.countLimit = 300
		return cache
	}()

	func cachedImage(for url: URL?) -> UIImage? {
		url.flatMap { cache.object(forKey: $0 as NSURL) }
	}

	func image(for url: URL) async -> UIImage? {
		if let image = cachedImage(for: url) { return image }
		guard
			let (data, _) = try? await URLSession.shared.data(from: url),
			let image = Self.decode(data)
		else { return nil }
		cache.setObject(image, forKey: url as NSURL)
		return image
	}

	private static func decode(_ data: Data) -> UIImage? {
		let options = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceShouldCacheImmediately: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
		] as CFDictionary
		guard
			let source = CGImageSourceCreateWithData(data as CFData, nil),
			let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
		else { return nil }
		return UIImage(cgImage: image)
	}
}

/// Fills the space it's given, cropping the image if needed.
struct RemoteImage: View {
	let url: URL?

	@State private var image: UIImage?

	init(url: URL?) {
		self.url = url
		_image = State(initialValue: ImageLoader.shared.cachedImage(for: url))
	}

	var body: some View {
		Palette.placeholder
			.overlay {
				if let image {
					Image(uiImage: image)
						.resizable()
						.scaledToFill()
				}
			}
			.clipped()
			.task(id: url) {
				guard let url else {
					image = nil
					return
				}
				if let loaded = await ImageLoader.shared.image(for: url) { image = loaded }
			}
	}
}
