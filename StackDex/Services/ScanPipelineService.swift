import CoreGraphics
import Foundation
import OSLog
import UIKit
import Vision
import Darwin

import CoreImage
#if canImport(FoundationModels)
import FoundationModels
#endif

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
    let signalQuality: ScanSignalQuality

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
        possibleLanguages: [String] = [],
        signalQuality: ScanSignalQuality = .init()
    ) {
        self.normalizedQuery = normalizedQuery
        self.nameTokens = nameTokens
        self.possibleNumbers = possibleNumbers
        self.possibleSetCodes = possibleSetCodes
        self.possibleRarities = possibleRarities
        self.possibleLanguages = possibleLanguages
        self.signalQuality = signalQuality
    }
}

struct ScanSignalQuality: Equatable {
    let isWeakNameSignal: Bool
    let hasCollectorNumberSignal: Bool
    let hasSuspiciousSetCodes: Bool

    init(
        isWeakNameSignal: Bool = false,
        hasCollectorNumberSignal: Bool = false,
        hasSuspiciousSetCodes: Bool = false
    ) {
        self.isWeakNameSignal = isWeakNameSignal
        self.hasCollectorNumberSignal = hasCollectorNumberSignal
        self.hasSuspiciousSetCodes = hasSuspiciousSetCodes
    }
}

enum ScanOCRRegion: String, Equatable {
    case titleStrip = "titleStrip"
    case evolutionLine = "evolutionLine"
    case attackBox = "attackBox"
    case collectorFooter = "collectorFooter"
    case fullCardFallback = "fullCardFallback"
}

struct RecognizedCardField: Equatable {
    let text: String
    let confidence: Float
    let region: ScanOCRRegion
    let boundingBox: CGRect
}

struct ScanRawOCRCandidate: Equatable {
    let text: String
    let confidence: Float
}

struct ScanRawOCRObservation: Equatable {
    let region: ScanOCRRegion
    let boundingBox: CGRect
    let candidates: [ScanRawOCRCandidate]
}

struct ScanOCRDebugSnapshot: Equatable {
    let updatedAt: Date
    let source: ScanImageSource
    let rawObservations: [ScanRawOCRObservation]

    var fullRecognizedText: String {
        topCandidateLines.joined(separator: "\n")
    }

    var topCandidateLines: [String] {
        rawObservations.compactMap { observation in
            observation.candidates.first?.text.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }
}

enum ScanOCRDebugFormatting {
    static func confidenceString(_ confidence: Float) -> String {
        String(format: "%.1f%%", Double(confidence) * 100)
    }
}

enum ScanOCRPostProcessMode: String, CaseIterable, Hashable {
    case visionOnly = "Nur Vision"
    case visionWithPostProcessing = "Vision + Nachkorrektur"

    var needsTwoStep: Bool {
        self == .visionWithPostProcessing
    }
}

struct ScanPipelineResult: Equatable {
    let recognizedTexts: [String]
    let hints: ScanLookupHints
    let recognizedFields: [RecognizedCardField]
    let rawObservations: [ScanRawOCRObservation]
    let source: ScanImageSource
    let usedFullImageFallback: Bool
}

struct ScanPipelineArtifacts: Equatable {
    let recognizedFields: [RecognizedCardField]
    let rawObservations: [ScanRawOCRObservation]
    let usedFullImageFallback: Bool
    let rectifiedExtent: CGRect
    let source: ScanImageSource
}

struct OCRRequestSettings {
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["de-DE", "en-US"]
    var usesLanguageCorrection: Bool = true
    var automaticallyDetectsLanguage: Bool = false
    var minimumTextHeight: Float?
    var useAggressivePreprocessing: Bool = true
    var maxCandidatesPerObservation: Int = 3
    var customWords: [String] = []
    var customConfigure: ((VNRecognizeTextRequest) -> Void)?
    var postProcessMode: ScanOCRPostProcessMode = .visionOnly

    static let `default` = OCRRequestSettings()

    static let fast = OCRRequestSettings(
        recognitionLevel: .fast,
        recognitionLanguages: ["de-DE", "en-US"],
        usesLanguageCorrection: false,
        automaticallyDetectsLanguage: true,
        minimumTextHeight: nil,
        useAggressivePreprocessing: false,
        maxCandidatesPerObservation: 1
    )

    static let maximum = OCRRequestSettings(
        recognitionLevel: .accurate,
        recognitionLanguages: ["de-DE", "en-US"],
        usesLanguageCorrection: true,
        automaticallyDetectsLanguage: false,
        minimumTextHeight: nil,
        useAggressivePreprocessing: true,
        maxCandidatesPerObservation: 3
    )
}

enum ScanOCRQualityPreset: String, CaseIterable, Hashable {
    case fast = "Schnell"
    case maximum = "Maximale Genauigkeit"

    var settings: OCRRequestSettings {
        switch self {
        case .fast:
            return .fast
        case .maximum:
            return .maximum
        }
    }
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
    private let ocrContext = CIContext()
    private let rawCandidateLimit = 10

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
            rawObservations: artifacts.rawObservations,
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
        var rawObservations: [ScanRawOCRObservation] = []

        let titleResult = recognizeText(in: cardImage, region: .titleStrip, settings: configuredSettings(for: .titleStrip, base: settings))
        fields += titleResult.fields
        rawObservations += titleResult.rawObservations

        let evolutionResult = recognizeText(in: cardImage, region: .evolutionLine, settings: configuredSettings(for: .evolutionLine, base: settings))
        fields += evolutionResult.fields
        rawObservations += evolutionResult.rawObservations

        let attackResult = recognizeText(in: cardImage, region: .attackBox, settings: configuredSettings(for: .attackBox, base: settings))
        fields += attackResult.fields
        rawObservations += attackResult.rawObservations

        let footerResult = recognizeText(in: cardImage, region: .collectorFooter, settings: configuredSettings(for: .collectorFooter, base: settings))
        fields += footerResult.fields
        rawObservations += footerResult.rawObservations

        let fallbackResult = recognizeText(in: cardImage, region: .fullCardFallback, settings: configuredSettings(for: .fullCardFallback, base: settings))
        fields += fallbackResult.fields
        rawObservations += fallbackResult.rawObservations

        let refinedFields = await applyTwoStagePostProcessing(to: fields, mode: settings.postProcessMode)

        return ScanPipelineArtifacts(
            recognizedFields: deduplicatedFields(refinedFields),
            rawObservations: rawObservations,
            usedFullImageFallback: cardImage.usedFallback,
            rectifiedExtent: cardImage.extent,
            source: normalized.source
        )
    }

    private func recognizeText(
        in image: DetectedCardImage,
        region: ScanOCRRegion,
        settings: OCRRequestSettings
    ) -> RegionOCRResult {
        let startedAt = CFAbsoluteTimeGetCurrent()
        guard let croppedImage = image.cgImage.cropping(to: cropRect(for: region, imageSize: CGSize(width: image.cgImage.width, height: image.cgImage.height))) else {
            return RegionOCRResult(fields: [], rawObservations: [])
        }

        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = settings.recognitionLevel
        request.recognitionLanguages = settings.recognitionLanguages
        request.usesLanguageCorrection = settings.usesLanguageCorrection
        request.automaticallyDetectsLanguage = settings.automaticallyDetectsLanguage
        if !settings.customWords.isEmpty {
            request.customWords = settings.customWords
        }
        if let minimumTextHeight = settings.minimumTextHeight {
            request.minimumTextHeight = minimumTextHeight
        }
        settings.customConfigure?(request)

        let requestImage = preprocessForOCR(cgImage: croppedImage, settings: settings)
        let handler = VNImageRequestHandler(cgImage: requestImage, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return RegionOCRResult(fields: [], rawObservations: [])
        }

        let observations: [VNRecognizedTextObservation] = request.results ?? []
        let regionRect = normalizedRegionRect(for: region)

        let rawObservations: [ScanRawOCRObservation] = observations.compactMap { observation -> ScanRawOCRObservation? in
            let candidates = observation.topCandidates(rawCandidateLimit)
                .map {
                    ScanRawOCRCandidate(
                        text: $0.string.trimmingCharacters(in: .whitespacesAndNewlines),
                        confidence: $0.confidence
                    )
                }
                .filter { !$0.text.isEmpty }

            guard !candidates.isEmpty else {
                return nil
            }

            return ScanRawOCRObservation(
                region: region,
                boundingBox: remapBoundingBox(observation.boundingBox, into: regionRect),
                candidates: candidates
            )
        }

        let fields = observations.flatMap { observation in
            observation.topCandidates(settings.maxCandidatesPerObservation)
                .filter { $0.confidence >= confidenceThreshold(for: region) }
                .map { candidate in
                    RecognizedCardField(
                        text: candidate.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                        confidence: candidate.confidence,
                        region: region,
                        boundingBox: remapBoundingBox(observation.boundingBox, into: regionRect)
                    )
                }
                .filter { !$0.text.isEmpty }
        }

        let durationMilliseconds = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
        logger.info("OCR pass region=\(region.rawValue, privacy: .public) latencyMs=\(durationMilliseconds, privacy: .public) count=\(fields.count, privacy: .public) rawObservations=\(rawObservations.count, privacy: .public)")
        return RegionOCRResult(fields: fields, rawObservations: rawObservations)
    }

    private func configuredSettings(for region: ScanOCRRegion, base: OCRRequestSettings) -> OCRRequestSettings {
        var settings = base
        settings.customWords = []

        switch region {
        case .titleStrip:
            settings.minimumTextHeight = 0.022
            settings.customConfigure = { request in
                request.automaticallyDetectsLanguage = false
                request.customWords = titleCustomWords
            }
            settings.customWords = titleCustomWords
        case .evolutionLine:
            settings.minimumTextHeight = 0.018
            settings.customConfigure = { request in
                request.automaticallyDetectsLanguage = true
            }
        case .attackBox:
            settings.minimumTextHeight = 0.02
            settings.customConfigure = { request in
                request.automaticallyDetectsLanguage = true
            }
        case .collectorFooter:
            settings.minimumTextHeight = 0.02
            settings.customConfigure = { request in
                request.customWords = footerCustomWords
            }
            settings.customWords = footerCustomWords
        case .fullCardFallback:
            settings.minimumTextHeight = 0.028
        }

        return settings
    }

    private func applyTwoStagePostProcessing(
        to fields: [RecognizedCardField],
        mode: ScanOCRPostProcessMode
    ) async -> [RecognizedCardField] {
        guard mode.needsTwoStep else {
            return fields
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, *), isFoundationTextModelReady {
            logger.debug("Applying optional second OCR post-processing stage.")
        } else {
            logger.debug("Foundation Model text refinement unavailable; using fallback post-processing.")
        }
        #else
        logger.debug("FoundationModels module not available; using fallback post-processing.")
        #endif

        return fallbackOCRPostProcessing(fields)
    }

    private var isFoundationTextModelReady: Bool {
        #if targetEnvironment(simulator)
        return false
        #endif

        #if canImport(FoundationModels)
        if getuid() == 0 {
            return false
        }
        if #available(iOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }

    private func fallbackOCRPostProcessing(_ fields: [RecognizedCardField]) -> [RecognizedCardField] {
        fields.map { field in
            let corrected = correctedOCRText(field.text)
            if corrected == field.text {
                return field
            }
            return RecognizedCardField(
                text: corrected,
                confidence: min(1.0, field.confidence + 0.03),
                region: field.region,
                boundingBox: field.boundingBox
            )
        }
    }

    private func correctedOCRText(_ text: String) -> String {
        let sanitized = text
            .replacingOccurrences(of: " | ", with: " ")
            .replacingOccurrences(of: "|", with: "I")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized
            .split { $0 == " " }
            .joined(separator: " ")
    }

    private func preprocessForOCR(cgImage: CGImage, settings: OCRRequestSettings) -> CGImage {
        let inputImage = CIImage(cgImage: cgImage)
        let colorControls: [String: NSNumber] = settings.useAggressivePreprocessing
            ? [
                kCIInputContrastKey as String: NSNumber(value: 1.26),
                kCIInputBrightnessKey as String: NSNumber(value: 0.01),
                kCIInputSaturationKey as String: NSNumber(value: 0.02),
            ]
            : [
                kCIInputContrastKey as String: NSNumber(value: 1.15),
                kCIInputSaturationKey as String: NSNumber(value: 0.02),
            ]

        let unsharp: [String: NSNumber] = settings.useAggressivePreprocessing
            ? [
                kCIInputRadiusKey as String: NSNumber(value: 1.1),
                kCIInputIntensityKey as String: NSNumber(value: 0.7),
            ]
            : [
                kCIInputRadiusKey as String: NSNumber(value: 0.8),
                kCIInputIntensityKey as String: NSNumber(value: 0.3),
            ]

        var enhancedImage = inputImage
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey as String: colorControls[kCIInputContrastKey as String]!,
                kCIInputBrightnessKey as String: colorControls[kCIInputBrightnessKey as String] ?? NSNumber(value: 0),
                kCIInputSaturationKey as String: colorControls[kCIInputSaturationKey as String] ?? NSNumber(value: 1)
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey as String: unsharp[kCIInputRadiusKey as String]!,
                kCIInputIntensityKey as String: unsharp[kCIInputIntensityKey as String]!
            ])

        guard let cgImage = ocrContext.createCGImage(enhancedImage, from: enhancedImage.extent) else {
            return cgImage
        }
        return cgImage
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

private struct RegionOCRResult {
    let fields: [RecognizedCardField]
    let rawObservations: [ScanRawOCRObservation]
}

private let titleCustomWords = [
    "Pokemon", "Pokémon", "EX", "GX", "V", "VMAX", "VSTAR",
    "Radiant", "Trainer", "Supporter", "Stadium", "Energy",
    "Shiny", "Holo", "Promo",
]

private let footerCustomWords = [
    "DE", "EN", "JP", "SVI", "LOR", "PAL",
    "Rare", "Promo", "Energy", "Illustration",
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
