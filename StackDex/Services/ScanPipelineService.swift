import Foundation
import UIKit
import Vision

enum ScanImageInput {
    case captured(UIImage)
    case imported(UIImage)

    var image: UIImage {
        switch self {
        case .captured(let image):
            return image
        case .imported(let image):
            return image
        }
    }
}

struct ScanLookupHints: Equatable {
    let normalizedQuery: String
    let nameTokens: [String]
    let possibleNumbers: [String]
}

struct ScanPipelineResult: Equatable {
    let recognizedTexts: [String]
    let hints: ScanLookupHints
}

struct OCRRequestSettings {
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["de-DE", "en-US"]
    var usesLanguageCorrection: Bool = true
    var minimumTextHeight: Float?
    var customConfigure: ((VNRecognizeTextRequest) -> Void)?

    static let `default` = OCRRequestSettings()
}

protocol ScanPipelineServing {
    func process(
        input: ScanImageInput,
        settings: OCRRequestSettings
    ) async throws -> ScanPipelineResult
}

enum ScanPipelineError: Error {
    case cgImageCreationFailed
}

struct VisionScanPipelineService: ScanPipelineServing {
    func process(
        input: ScanImageInput,
        settings: OCRRequestSettings = .default
    ) async throws -> ScanPipelineResult {
        guard let cgImage = input.image.cgImage else {
            throw ScanPipelineError.cgImageCreationFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = settings.recognitionLevel
        request.recognitionLanguages = settings.recognitionLanguages
        request.usesLanguageCorrection = settings.usesLanguageCorrection
        if let minimumTextHeight = settings.minimumTextHeight {
            request.minimumTextHeight = minimumTextHeight
        }
        settings.customConfigure?(request)

        let orientation = CGImagePropertyOrientation(input.image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])

        let observations = request.results ?? []
        let recognizedTexts = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let hints = buildHints(from: recognizedTexts)
        return ScanPipelineResult(recognizedTexts: recognizedTexts, hints: hints)
    }

    private func buildHints(from recognizedTexts: [String]) -> ScanLookupHints {
        let joined = recognizedTexts.joined(separator: " ")
        let compactQuery = joined
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = compactQuery
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }

        let numbers = words.filter {
            $0.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        }

        return ScanLookupHints(
            normalizedQuery: compactQuery,
            nameTokens: Array(words.prefix(8)),
            possibleNumbers: Array(numbers.prefix(4))
        )
    }
}

private extension CGImagePropertyOrientation {
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
