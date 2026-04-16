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
    private let idealCardAspect: CGFloat = 0.714

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
        let segmentationObservations = try segmentationRectangles(in: cgImage)
        if let dominantFromSegmentation = bestRectangle(
            from: segmentationObservations,
            minimumArea: 0.05,
            maximumArea: 0.96,
            relaxedAspect: false
        ) {
            return dominantFromSegmentation
        }

        let geometricStrict = try geometricRectangles(
            in: cgImage,
            minimumSize: 0.08,
            minimumConfidence: 0.5,
            quadratureTolerance: 30
        )
        if let dominantStrict = bestRectangle(
            from: geometricStrict,
            minimumArea: 0.06,
            maximumArea: 0.96,
            relaxedAspect: false
        ) {
            return dominantStrict
        }

        let geometricRelaxed = try geometricRectangles(
            in: cgImage,
            minimumSize: 0.05,
            minimumConfidence: 0.32,
            quadratureTolerance: 45
        )
        return bestRectangle(
            from: geometricRelaxed,
            minimumArea: 0.035,
            maximumArea: 0.96,
            relaxedAspect: true
        )
    }

    private func segmentationRectangles(in cgImage: CGImage) throws -> [VNRectangleObservation] {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        return request.results ?? []
    }

    private func geometricRectangles(
        in cgImage: CGImage,
        minimumSize: Float,
        minimumConfidence: Float,
        quadratureTolerance: Float
    ) throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 12
        request.minimumSize = minimumSize
        request.minimumConfidence = minimumConfidence
        request.minimumAspectRatio = 0.5
        request.quadratureTolerance = quadratureTolerance

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])
        return request.results ?? []
    }

    private func bestRectangle(
        from observations: [VNRectangleObservation],
        minimumArea: CGFloat,
        maximumArea: CGFloat,
        relaxedAspect: Bool
    ) -> VNRectangleObservation? {
        let filtered = observations.filter { observation in
            let area = observation.boundingBox.width * observation.boundingBox.height
            return area >= minimumArea
                && area <= maximumArea
                && isPlausibleCardAspect(observation.boundingBox, relaxed: relaxedAspect)
        }

        return filtered.max { lhs, rhs in
            rectangleScore(lhs.boundingBox) < rectangleScore(rhs.boundingBox)
        }
    }

    private func isPlausibleCardAspect(_ rect: CGRect, relaxed: Bool) -> Bool {
        let aspect = rect.width / max(rect.height, 0.001)
        if relaxed {
            return (0.5 ... 0.95).contains(aspect) || (1.05 ... 2.0).contains(aspect)
        }
        return (0.55 ... 0.9).contains(aspect) || (1.15 ... 1.65).contains(aspect)
    }

    private func rectangleScore(_ rect: CGRect) -> CGFloat {
        let area = rect.width * rect.height
        let aspect = rect.width / max(rect.height, 0.001)
        let normalizedAspect = min(aspect, 1 / max(aspect, 0.001))
        let distance = abs(normalizedAspect - idealCardAspect)
        let closeness = max(0.45, 1 - min(distance / idealCardAspect, 0.55))
        return area * closeness
    }

    private func point(_ normalized: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: normalized.x * width, y: normalized.y * height)
    }
}
