import CoreImage
import ImageIO
import UIKit

enum ScanImageSource {
    case captured
    case imported
}

struct NormalizedScanImage {
    let uiImage: UIImage
    let cgImage: CGImage
    let orientation: CGImagePropertyOrientation
    let source: ScanImageSource
}

enum ScanImagePreprocessorError: Error {
    case cgImageCreationFailed
}

struct ScanImagePreprocessor {
    private let context = CIContext()
    private let maximumDimension: CGFloat

    init(maximumDimension: CGFloat = 2200) {
        self.maximumDimension = maximumDimension
    }

    func normalize(input: ScanImageInput) throws -> NormalizedScanImage {
        let sourceImage = input.image
        let originalOrientation = CGImagePropertyOrientation(sourceImage.imageOrientation)

        let ciImage = try makeCIImage(from: sourceImage)
            .oriented(originalOrientation)
        let scaledImage = downscaledIfNeeded(ciImage)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.08,
                kCIInputSaturationKey: 0.95,
            ])

        let extent = scaledImage.extent.integral
        guard let cgImage = context.createCGImage(scaledImage, from: extent) else {
            throw ScanImagePreprocessorError.cgImageCreationFailed
        }

        return NormalizedScanImage(
            uiImage: UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: .up),
            cgImage: cgImage,
            orientation: .up,
            source: input.source
        )
    }

    static func image(from data: Data, orientation: CGImagePropertyOrientation) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage, scale: 1, orientation: UIImage.Orientation(orientation))
    }

    private func makeCIImage(from image: UIImage) throws -> CIImage {
        if let ciImage = image.ciImage {
            return ciImage
        }
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        if let cgImage = rendered.cgImage {
            return CIImage(cgImage: cgImage)
        }

        throw ScanImagePreprocessorError.cgImageCreationFailed
    }

    private func downscaledIfNeeded(_ image: CIImage) -> CIImage {
        let longestEdge = max(image.extent.width, image.extent.height)
        guard longestEdge > maximumDimension else {
            return image
        }

        let scale = maximumDimension / longestEdge
        return image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1,
        ])
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

private extension UIImage.Orientation {
    init(_ orientation: CGImagePropertyOrientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
