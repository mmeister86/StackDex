import CoreGraphics
import Foundation
import OSLog
import UIKit
import Vision

enum ScanImageInput {
    case captured(UIImage)
    case imported(UIImage)

    var image: UIImage {
        switch self {
        case .captured(let image), .imported(let image):
            return image
        }
    }

    var source: ScanImageSource {
        switch self {
        case .captured:
            return .captured
        case .imported:
            return .imported
        }
    }
}

struct ScanLookupHints: Equatable {
    let normalizedQuery: String
    let nameTokens: [String]
    let possibleNumbers: [String]
    let possibleSetCodes: [String]
    let possibleRarities: [String]
    let possibleLanguages: [String]

    var hasNameSignal: Bool {
        !nameTokens.isEmpty
    }

    var hasCollectorNumberSignal: Bool {
        possibleNumbers.contains(where: { $0.contains("/") })
    }

    var hasStrongLookupSignal: Bool {
        hasNameSignal || hasCollectorNumberSignal
    }

    init(
        normalizedQuery: String,
        nameTokens: [String],
        possibleNumbers: [String],
        possibleSetCodes: [String] = [],
        possibleRarities: [String] = [],
        possibleLanguages: [String] = []
    ) {
        self.normalizedQuery = normalizedQuery
        self.nameTokens = nameTokens
        self.possibleNumbers = possibleNumbers
        self.possibleSetCodes = possibleSetCodes
        self.possibleRarities = possibleRarities
        self.possibleLanguages = possibleLanguages
    }
}

struct ScanPipelineResult: Equatable {
    let recognizedTexts: [String]
    let hints: ScanLookupHints
    let recognizedFields: [RecognizedCardField]
    let source: ScanImageSource
    let usedFullImageFallback: Bool
}

struct ScanPipelineArtifacts: Equatable {
    let recognizedFields: [RecognizedCardField]
    let usedFullImageFallback: Bool
    let rectifiedExtent: CGRect
    let source: ScanImageSource
}

struct OCRRequestSettings {
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["de-DE", "en-US"]
    var usesLanguageCorrection: Bool = false
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
    private let logger = Logger(subsystem: "de.stackdex.app", category: "scan.pipeline")
    private let preprocessor: ScanImagePreprocessor
    private let detector: CardRegionDetector
    private let queryBuilder: ScanQueryBuilder

    init(
        preprocessor: ScanImagePreprocessor = ScanImagePreprocessor(),
        detector: CardRegionDetector = CardRegionDetector(),
        queryBuilder: ScanQueryBuilder = ScanQueryBuilder()
    ) {
        self.preprocessor = preprocessor
        self.detector = detector
        self.queryBuilder = queryBuilder
    }

    func process(
        input: ScanImageInput,
        settings: OCRRequestSettings = .default
    ) async throws -> ScanPipelineResult {
        let artifacts = try await inspect(input: input, settings: settings)
        let recognizedTexts = deduplicatedTexts(from: artifacts.recognizedFields)
        let hints = queryBuilder.buildHints(from: artifacts.recognizedFields)
        logger.info("Selected structured query=\(hints.normalizedQuery, privacy: .public) source=\(artifacts.source.logName, privacy: .public) fields=\(artifacts.recognizedFields.count, privacy: .public)")
        return ScanPipelineResult(
            recognizedTexts: recognizedTexts,
            hints: hints,
            recognizedFields: artifacts.recognizedFields,
            source: artifacts.source,
            usedFullImageFallback: artifacts.usedFullImageFallback
        )
    }

    func inspect(
        input: ScanImageInput,
        settings: OCRRequestSettings = .default
    ) async throws -> ScanPipelineArtifacts {
        let normalized = try preprocessor.normalize(input: input)
        let cardImage = try detector.detectAndRectify(from: normalized)
        logger.info("Scan source=\(normalized.source.logName, privacy: .public) detectorFallback=\(cardImage.usedFallback, privacy: .public)")

        var fields: [RecognizedCardField] = []
        fields += recognizeText(in: cardImage, region: .titleStrip, settings: configuredSettings(for: .titleStrip, base: settings))
        fields += recognizeText(in: cardImage, region: .evolutionLine, settings: configuredSettings(for: .evolutionLine, base: settings))
        fields += recognizeText(in: cardImage, region: .attackBox, settings: configuredSettings(for: .attackBox, base: settings))
        fields += recognizeText(in: cardImage, region: .collectorFooter, settings: configuredSettings(for: .collectorFooter, base: settings))
        fields += recognizeText(in: cardImage, region: .fullCardFallback, settings: configuredSettings(for: .fullCardFallback, base: settings))

        return ScanPipelineArtifacts(
            recognizedFields: deduplicatedFields(fields),
            usedFullImageFallback: cardImage.usedFallback,
            rectifiedExtent: cardImage.extent,
            source: normalized.source
        )
    }

    private func recognizeText(
        in image: DetectedCardImage,
        region: ScanOCRRegion,
        settings: OCRRequestSettings
    ) -> [RecognizedCardField] {
        let startedAt = CFAbsoluteTimeGetCurrent()
        guard let croppedImage = image.cgImage.cropping(to: cropRect(for: region, imageSize: CGSize(width: image.cgImage.width, height: image.cgImage.height))) else {
            return []
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = settings.recognitionLevel
        request.recognitionLanguages = settings.recognitionLanguages
        request.usesLanguageCorrection = settings.usesLanguageCorrection
        if let minimumTextHeight = settings.minimumTextHeight {
            request.minimumTextHeight = minimumTextHeight
        }
        settings.customConfigure?(request)

        let handler = VNImageRequestHandler(cgImage: croppedImage, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let observations = request.results ?? []
        let regionRect = normalizedRegionRect(for: region)

        let fields = observations.flatMap { observation in
            observation.topCandidates(2)
                .filter { $0.confidence >= confidenceThreshold(for: region) }
                .map { candidate in
                    RecognizedCardField(
                        text: candidate.string.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: candidate.confidence,
                        region: region,
                        boundingBox: remapBoundingBox(observation.boundingBox, into: regionRect)
                    )
                }
                .filter { !$0.text.isEmpty }
        }

        let durationMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
        logger.info("OCR pass region=\(region.rawValue, privacy: .public) latencyMs=\(durationMilliseconds, privacy: .public) count=\(fields.count, privacy: .public)")
        return fields
    }

    private func configuredSettings(for region: ScanOCRRegion, base: OCRRequestSettings) -> OCRRequestSettings {
        var settings = base
        settings.recognitionLevel = .accurate
        settings.recognitionLanguages = ["de-DE", "en-US"]
        settings.usesLanguageCorrection = false

        switch region {
        case .titleStrip:
            settings.usesLanguageCorrection = true
            settings.minimumTextHeight = 0.022
            settings.customConfigure = { request in
                request.customWords = nameCustomWords
                request.automaticallyDetectsLanguage = true
            }
        case .collectorFooter:
            settings.minimumTextHeight = 0.02
        case .evolutionLine:
            settings.minimumTextHeight = 0.018
        case .attackBox:
            settings.minimumTextHeight = 0.02
        case .fullCardFallback:
            settings.minimumTextHeight = 0.028
        }

        return settings
    }

    private func confidenceThreshold(for region: ScanOCRRegion) -> Float {
        switch region {
        case .titleStrip:
            return 0.28
        case .collectorFooter:
            return 0.34
        case .evolutionLine, .attackBox:
            return 0.36
        case .fullCardFallback:
            return 0.44
        }
    }

    private func cropRect(for region: ScanOCRRegion, imageSize: CGSize) -> CGRect {
        let normalized = normalizedRegionRect(for: region)
        return CGRect(
            x: normalized.minX * imageSize.width,
            y: normalized.minY * imageSize.height,
            width: normalized.width * imageSize.width,
            height: normalized.height * imageSize.height
        ).integral
    }

    private func normalizedRegionRect(for region: ScanOCRRegion) -> CGRect {
        switch region {
        case .titleStrip:
            return CGRect(x: 0.04, y: 0.02, width: 0.92, height: 0.2)
        case .evolutionLine:
            return CGRect(x: 0.06, y: 0.2, width: 0.88, height: 0.1)
        case .attackBox:
            return CGRect(x: 0.06, y: 0.38, width: 0.88, height: 0.38)
        case .collectorFooter:
            return CGRect(x: 0.04, y: 0.74, width: 0.92, height: 0.22)
        case .fullCardFallback:
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    private func remapBoundingBox(_ observation: CGRect, into region: CGRect) -> CGRect {
        CGRect(
            x: region.minX + (observation.minX * region.width),
            y: region.minY + (observation.minY * region.height),
            width: observation.width * region.width,
            height: observation.height * region.height
        )
    }

    private func deduplicatedTexts(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var texts: [String] = []
        for field in fields.sorted(by: fieldPriority) {
            guard field.region == .titleStrip || field.region == .collectorFooter else {
                continue
            }
            let normalized = field.text.lowercased()
            guard seen.insert(normalized).inserted else { continue }
            texts.append(field.text)
        }
        return texts
    }

    private func deduplicatedFields(_ fields: [RecognizedCardField]) -> [RecognizedCardField] {
        var bestByText: [String: RecognizedCardField] = [:]
        for field in fields where !field.text.isEmpty {
            let key = "\(field.region.rawValue)|\(field.text.lowercased())"
            if let existing = bestByText[key], !fieldPriority(field, existing) {
                continue
            }
            bestByText[key] = field
        }
        return bestByText.values.sorted(by: fieldPriority)
    }

    private func fieldPriority(_ lhs: RecognizedCardField, _ rhs: RecognizedCardField) -> Bool {
        let regionRank: [ScanOCRRegion: Int] = [
            .titleStrip: 6,
            .collectorFooter: 5,
            .evolutionLine: 2,
            .attackBox: 1,
            .fullCardFallback: 0,
        ]
        let lhsRank = regionRank[lhs.region, default: 0]
        let rhsRank = regionRank[rhs.region, default: 0]
        if lhsRank != rhsRank {
            return lhsRank > rhsRank
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return lhs.text.count > rhs.text.count
    }
}

private let nameCustomWords = [
    "Pokemon", "Pokémon", "EX", "GX", "V", "VMAX", "VSTAR",
    "Radiant", "Trainer", "Supporter", "Stadium", "Energy",
    "Shiny", "Holo", "Promo",
]

private extension ScanImageSource {
    var logName: String {
        switch self {
        case .captured:
            return "captured"
        case .imported:
            return "imported"
        }
    }
}
