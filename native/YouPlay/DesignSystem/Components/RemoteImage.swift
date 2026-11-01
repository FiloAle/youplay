import ImageIO
import SwiftUI

/// Downloads images once and keeps them decoded and downsampled, so lists scroll without flashes.
/// `NSCache` is thread-safe, which makes this safe to share.
final class ImageLoader: @unchecked Sendable {
	static let shared = ImageLoader()

	// Enough for a full-width thumbnail at 3x, and no more: decoded images are what fills the memory.
	private static let maxPixelSize = 1200
	private static let cacheLimit = 200 * 1024 * 1024

	private let cache: NSCache<NSURL, UIImage> = {
		let cache = NSCache<NSURL, UIImage>()
		cache.totalCostLimit = cacheLimit
		return cache
	}()

	func cachedImage(for url: URL?) -> UIImage? {
		url.flatMap { cache.object(forKey: $0 as NSURL) }
	}

	/// A fallback that gets used is cached under `url`, so that a missing image is only requested once.
	func image(for url: URL, fallback: URL? = nil) async -> UIImage? {
		if let image = cachedImage(for: url) { return image }

		var image = await Self.download(url)
		if image == nil, let fallback, !Task.isCancelled {
			image = await Self.download(fallback)
		}
		guard let image else { return nil }

		let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
		cache.setObject(image, forKey: url as NSURL, cost: cost)
		return image
	}

	private static func download(_ url: URL) async -> UIImage? {
		guard
			let (data, response) = try? await URLSession.shared.data(from: url),
			(response as? HTTPURLResponse)?.statusCode == 200
		else { return nil }
		return decode(data)
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
	var fallbackURL: URL?

	@State private var image: UIImage?

	init(url: URL?, fallbackURL: URL? = nil) {
		self.url = url
		self.fallbackURL = fallbackURL
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
				if let loaded = await ImageLoader.shared.image(for: url, fallback: fallbackURL) { image = loaded }
			}
	}
}
