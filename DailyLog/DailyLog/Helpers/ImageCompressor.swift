import UIKit

struct ImageCompressor {
    /// Compresses an image to approximately the target size in bytes (default ~500KB).
    static func compress(_ image: UIImage, targetBytes: Int = 500_000) -> Data? {
        // First, resize if the image is very large
        let maxDimension: CGFloat = 1200
        let resized = resizeIfNeeded(image, maxDimension: maxDimension)

        // Try compressing with decreasing quality until under target
        var quality: CGFloat = 0.8
        var data = resized.jpegData(compressionQuality: quality)

        while let d = data, d.count > targetBytes, quality > 0.1 {
            quality -= 0.1
            data = resized.jpegData(compressionQuality: quality)
        }

        return data
    }

    private static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let aspectRatio = size.width / size.height
        let newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
