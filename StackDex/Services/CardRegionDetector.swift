import CoreImage
import CoreGraphics
import Vision

struct DetectedCardImage {
    let cgImage: CGImage
    let extent: CGRect
    let usedFallback: Bool
}

struct CardRegionDetector {
    private let context = CIContext()

    func detectAndRectify(from image: NormalizedScanImage) throws -> DetectedCardImage {
        guard let rectangle = try dominantRectangle(in: image.cgImage) else {
            return DetectedCardImage(
                cgImage: image.cgImage,
                extent: CGRect(x: 0, y: 0, width: image.cgImage.width, height: image.cgImage.height),
                usedFallback: true
            )
        }

        let ciImage = CIImage(cgImage: image.cgImage)
        let width = CGFloat(image.cgImage.width)
        let height = CGFloat(image.cgImage.height)
        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: point(rectangle.topLeft, width: width, height: height)),
            "inputTopRight": CIVector(cgPoint: point(rectangle.topRight, width: width, height: height)),
            "inputBottomLeft": CIVector(cgPoint: point(rectangle.bottomLeft, width: width, height: height)),
            "inputBottomRight": CIVector(cgPoint: point(rectangle.bottomRight, width: width, height: height)),
        ])

        let extent = corrected.extent.integral
        guard extent.width > 0,
              extent.height > 0,
              let cgImage = context.createCGImage(corrected, from: extent) else {
            return DetectedCardImage(
                cgImage: image.cgImage,
                extent: CGRect(x: 0, y: 0, width: image.cgImage.width, height: image.cgImage.height),
                usedFallback: true
            )
        }

        return DetectedCardImage(cgImage: cgImage, extent: extent, usedFallback: false)
    }

    private func dominantRectangle(in cgImage: CGImage) throws -> VNRectangleObservation? {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])

        let observations = (request.results ?? []).filter { observation in
            let area = observation.boundingBox.width * observation.boundingBox.height
            let aspect = observation.boundingBox.width / max(observation.boundingBox.height, 0.001)
            let plausibleAspect = (0.55 ... 0.9).contains(aspect) || (1.15 ... 1.65).contains(aspect)
            return area >= 0.2 && plausibleAspect
        }
        return observations.max { lhs, rhs in
            lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
        }
    }

    private func point(_ normalized: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: normalized.x * width, y: normalized.y * height)
    }
}
