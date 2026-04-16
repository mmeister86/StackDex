import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import StackDex

@MainActor @Suite(.serialized)
struct VisionScanPipelineServiceTests {
    private let service = VisionScanPipelineService()
    private let preprocessor = ScanImagePreprocessor()

    @Test func topBandCardNameSurvivesOCR() async throws {
        let image = TestCardImageFactory.makeCardImage(name: "Pikachu ex", collectorNumber: "199/091")

        let artifacts = try await service.inspect(input: .captured(image))

        let nameTexts = artifacts.recognizedFields
            .filter { $0.region == .nameBand }
            .map { $0.text.lowercased() }
        #expect(nameTexts.contains(where: { $0.contains("pikachu") }))
    }

    @Test func bottomBandCollectorNumberSurvivesOCR() async throws {
        let image = TestCardImageFactory.makeCardImage(name: "Pikachu ex", collectorNumber: "199/091")

        let result = try await service.process(input: .captured(image), settings: .default)

        #expect(result.hints.possibleNumbers.contains("199/091"))
    }

    @Test func noisyBodyTextDoesNotDominateStructuredQuery() async throws {
        let fields: [RecognizedCardField] = [
            .init(text: "Pikachu ex", confidence: 0.96, region: .nameBand, boundingBox: CGRect(x: 0.1, y: 0.05, width: 0.7, height: 0.1)),
            .init(text: "Thunderbolt spark charge", confidence: 0.91, region: .fullCardFallback, boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.3)),
            .init(text: "199/091", confidence: 0.89, region: .numberBandLeft, boundingBox: CGRect(x: 0.68, y: 0.88, width: 0.2, height: 0.06)),
        ]

        let hints = ScanQueryBuilder().buildHints(from: fields)

        #expect(hints.normalizedQuery.lowercased().contains("pikachu ex"))
        #expect(hints.normalizedQuery.contains("199/091"))
        #expect(!hints.normalizedQuery.lowercased().contains("thunderbolt spark charge"))
    }

    @Test func footerBandsProvideSetCodeLanguageAndRarityHints() async throws {
        let image = TestCardImageFactory.makeCardImage(
            name: "Pikachu ex",
            collectorNumber: "199/091",
            footerLeft: "SVI DE 199/091",
            footerRight: "Illustration Rare"
        )

        let result = try await service.process(input: .captured(image), settings: .default)

        #expect(result.hints.possibleSetCodes.contains("SVI"))
        #expect(result.hints.possibleLanguages.contains("DE"))
        #expect(result.hints.possibleRarities.contains("Illustration Rare"))
    }

    @Test func importedOrientationNormalizesToUprightOCRContract() throws {
        let base = TestCardImageFactory.makeCardImage(name: "Eevee", collectorNumber: "111/131")
        let rotated = try #require(base.cgImage)
        let oriented = UIImage(cgImage: rotated, scale: 1, orientation: .right)

        let normalized = try preprocessor.normalize(input: .imported(oriented))

        #expect(normalized.orientation == .up)
        #expect(normalized.uiImage.imageOrientation == .up)
        #expect(normalized.cgImage.width > 0)
        #expect(normalized.cgImage.height > 0)
    }

    @Test func detectorFallsBackCleanlyWhenNoCardRegionFound() async throws {
        let noiseOnly = TestCardImageFactory.makeNoiseImage()

        let artifacts = try await service.inspect(input: .captured(noiseOnly))

        #expect(artifacts.usedFullImageFallback)
    }

    @Test func detectorRectifiesSkewedCardBeforeOCR() async throws {
        let skewed = TestCardImageFactory.makeSkewedCardImage(name: "Charizard ex", collectorNumber: "006/165")

        let artifacts = try await service.inspect(input: .captured(skewed))

        #expect(artifacts.rectifiedExtent.width > 0)
        #expect(artifacts.rectifiedExtent.height > 0)
        #expect(artifacts.recognizedFields.contains(where: { $0.text.lowercased().contains("charizard") }))
    }

    @Test func screenshotLikeInputRejectsHeaderChromeAndKeepsCollectorNumber() async throws {
        let screenshotLike = TestCardImageFactory.makeScreenshotLikeImage(
            name: "Dragoran",
            collectorNumber: "131/195",
            headerLeft: "Gespeicherte Elemente",
            headerRight: "Gate to the Games"
        )

        let result = try await service.process(input: .imported(screenshotLike), settings: .default)
        let loweredNameTokens = result.hints.nameTokens.map { $0.lowercased() }

        #expect(result.hints.possibleNumbers.contains("131/195"))
        #expect(!loweredNameTokens.contains("gespeicherte"))
        #expect(!result.hints.normalizedQuery.lowercased().contains("gespeicherte"))
    }
}

private enum TestCardImageFactory {
    static func makeCardImage(
        name: String,
        collectorNumber: String,
        footerLeft: String? = nil,
        footerRight: String? = nil
    ) -> UIImage {
        let canvasSize = CGSize(width: 1400, height: 1000)
        let cardRect = CGRect(x: 220, y: 120, width: 960, height: 680)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { context in
            UIColor(red: 0.84, green: 0.87, blue: 0.92, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            UIColor(red: 0.77, green: 0.81, blue: 0.87, alpha: 0.45).setFill()
            for index in 0 ..< 24 {
                let stripeY = CGFloat(index) * 42
                context.fill(CGRect(x: 0, y: stripeY, width: canvasSize.width, height: 18))
            }

            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 24)
            UIColor.white.setFill()
            cardPath.fill()

            UIColor(white: 0.86, alpha: 1).setStroke()
            cardPath.lineWidth = 4
            cardPath.stroke()

            drawText(name, in: CGRect(x: cardRect.minX + 48, y: cardRect.minY + 28, width: cardRect.width - 96, height: 104), fontSize: 64, weight: .bold)

            let noisyBody = Array(repeating: "thunderbolt spark charge attack retreat ability", count: 8).joined(separator: " ")
            drawText(noisyBody, in: CGRect(x: cardRect.minX + 52, y: cardRect.minY + 210, width: cardRect.width - 104, height: 250), fontSize: 24, weight: .regular, color: UIColor(white: 0.32, alpha: 1))

            if let footerLeft, !footerLeft.isEmpty {
                drawText(footerLeft, in: CGRect(x: cardRect.minX + 44, y: cardRect.maxY - 112, width: 420, height: 64), fontSize: 30, weight: .bold)
            }

            let rightFooter = footerRight ?? collectorNumber
            drawText(rightFooter, in: CGRect(x: cardRect.maxX - 360, y: cardRect.maxY - 112, width: 320, height: 64), fontSize: 28, weight: .bold)
        }
    }

    static func makeSkewedCardImage(name: String, collectorNumber: String) -> UIImage {
        let canvasSize = CGSize(width: 1400, height: 1000)
        let cardRect = CGRect(x: 0, y: 0, width: 960, height: 680)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            UIColor(red: 0.84, green: 0.87, blue: 0.92, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
            context.cgContext.rotate(by: 0.18)
            context.cgContext.translateBy(x: -cardRect.width / 2, y: -cardRect.height / 2)

            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 24)
            UIColor.white.setFill()
            path.fill()
            UIColor(white: 0.84, alpha: 1).setStroke()
            path.lineWidth = 5
            path.stroke()

            drawText(name, in: CGRect(x: 48, y: 28, width: cardRect.width - 96, height: 104), fontSize: 64, weight: .bold)
            let noisyBody = Array(repeating: "dragon fire blast energy retreat ability", count: 8).joined(separator: " ")
            drawText(noisyBody, in: CGRect(x: 52, y: 210, width: cardRect.width - 104, height: 250), fontSize: 24, weight: .regular, color: UIColor(white: 0.32, alpha: 1))
            drawText(collectorNumber, in: CGRect(x: cardRect.maxX - 300, y: cardRect.maxY - 112, width: 250, height: 64), fontSize: 42, weight: .bold)

            context.cgContext.restoreGState()
        }
    }

    static func makeNoiseImage() -> UIImage {
        let size = CGSize(width: 1200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.13, green: 0.15, blue: 0.2, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            for index in 0 ..< 80 {
                let hue = CGFloat(index) / 80
                UIColor(hue: hue, saturation: 0.45, brightness: 0.82, alpha: 0.95).setFill()
                let rect = CGRect(
                    x: CGFloat((index * 97) % 1000),
                    y: CGFloat((index * 53) % 760),
                    width: CGFloat(80 + (index % 5) * 20),
                    height: CGFloat(30 + (index % 7) * 15)
                )
                context.fill(rect)
            }
        }
    }

    static func makeScreenshotLikeImage(
        name: String,
        collectorNumber: String,
        headerLeft: String,
        headerRight: String
    ) -> UIImage {
        let canvasSize = CGSize(width: 1800, height: 1400)
        let embeddedCard = makeCardImage(name: name, collectorNumber: collectorNumber)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            UIColor(white: 0.96, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            drawText(headerLeft, in: CGRect(x: 120, y: 54, width: 700, height: 90), fontSize: 56, weight: .bold, color: UIColor(white: 0.16, alpha: 1))
            drawText(headerRight, in: CGRect(x: 940, y: 70, width: 700, height: 90), fontSize: 42, weight: .semibold, color: UIColor(white: 0.2, alpha: 1))

            let cardFrame = CGRect(x: 280, y: 220, width: 1240, height: 980)
            UIColor(white: 1, alpha: 1).setFill()
            UIBezierPath(roundedRect: cardFrame, cornerRadius: 20).fill()
            embeddedCard.draw(in: cardFrame.insetBy(dx: 26, dy: 26))
        }
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        fontSize: CGFloat,
        weight: UIFont.Weight,
        color: UIColor = .black
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]

        NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }
}
