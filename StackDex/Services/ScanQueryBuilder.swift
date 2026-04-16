import CoreGraphics
import Foundation

enum ScanOCRRegion: String, Equatable {
    case titleStrip
    case evolutionLine
    case attackBox
    case collectorFooter
    case fullCardFallback
}

struct RecognizedCardField: Equatable {
    let text: String
    let confidence: Float
    let region: ScanOCRRegion
    let boundingBox: CGRect
}

struct ScanQueryBuilder {
    private let languageTokens: Set<String> = ["DE", "EN"]
    private let rarityTokens: Set<String> = [
        "common", "uncommon", "rare", "double rare", "ultra rare", "illustration rare",
        "special illustration rare", "hyper rare", "holo rare", "promo", "amazing rare", "prism star",
    ]
    private let noisyBodyKeywords: Set<String> = [
        "attack", "ability", "retreat", "damage", "charge", "cost", "coin", "energy", "trainer",
        "pokemon", "this", "card", "dein", "deine", "deiner", "deines", "angriff", "schaden",
        "energie", "rueckzug", "regel", "during", "turn", "active", "bench", "flip",
    ]
    private let setCodeStopWords: Set<String> = [
        "UND", "ODER", "DIE", "DER", "DAS", "DEN", "DES", "DEM", "EIN", "EINE", "EINEM",
        "ZUR", "ZUM", "VON", "MIT", "AUS", "DU", "AUR", "THE", "AND", "FOR", "WITH", "YOUR", "YOU",
    ]
    private let uiNoiseNameTokens: Set<String> = [
        "gespeicherte", "elemente", "gate", "games", "kamera", "camera", "foto", "photo",
        "suche", "search", "ergebnis", "result", "collection", "album", "library",
    ]
    private let fallbackNameStopWords: Set<String> = [
        "nimmt", "jener", "spieler", "preiskarte", "preis", "karten", "karte", "gegner",
        "dein", "deine", "deiner", "deines", "deinen", "when", "your", "opponent", "damage",
        "attack", "ability", "effects", "effekt", "stapelt", "nicht",
    ]
    private let nameSuffixTokens: Set<String> = ["ex", "gx", "v", "vmax", "vstar", "lv", "lvl", "star"]
    private let nameSentenceStopWords: Set<String> = [
        "sich", "aus", "von", "vom", "zur", "zum", "the", "of", "from",
        "during", "this", "your", "if",
    ]

    func buildHints(from fields: [RecognizedCardField]) -> ScanLookupHints {
        let cleanedFields = fields
            .map {
                RecognizedCardField(
                    text: normalizeWhitespace($0.text),
                    confidence: $0.confidence,
                    region: $0.region,
                    boundingBox: $0.boundingBox
                )
            }
            .filter { !$0.text.isEmpty }

        let preferredName = preferredName(from: cleanedFields)
        let possibleNumbers = numberCandidates(from: cleanedFields)
        let possibleSetCodes = setCodeCandidates(from: cleanedFields)
        let possibleRarities = rarityCandidates(from: cleanedFields)
        let possibleLanguages = languageCandidates(from: cleanedFields)

        let normalizedQuery = structuredQuery(
            preferredName: preferredName,
            possibleNumbers: possibleNumbers,
            possibleSetCodes: possibleSetCodes
        )

        let nameTokens: [String]
        if let preferredName {
            let parsedNameTokens = tokenizeName(preferredName)
            nameTokens = parsedNameTokens.isEmpty ? (normalizedQuery.isEmpty ? [] : tokenizeName(normalizedQuery)) : parsedNameTokens
        } else {
            nameTokens = normalizedQuery.isEmpty ? [] : tokenizeName(normalizedQuery)
        }

        return ScanLookupHints(
            normalizedQuery: normalizedQuery,
            nameTokens: nameTokens,
            possibleNumbers: possibleNumbers,
            possibleSetCodes: possibleSetCodes,
            possibleRarities: possibleRarities,
            possibleLanguages: possibleLanguages
        )
    }

    private func preferredName(from fields: [RecognizedCardField]) -> String? {
        let bestInTitleStrip = fields
            .filter { $0.region == .titleStrip }
            .sorted(by: fieldPriority)
            .first(where: { looksLikeNameField($0.text) })

        if let bestInTitleStrip {
            return bestInTitleStrip.text
        }

        return nil
    }

    private func structuredQuery(
        preferredName: String?,
        possibleNumbers: [String],
        possibleSetCodes: [String]
    ) -> String {
        let trimmedName = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let number = possibleNumbers.first
        let setCode = possibleSetCodes.first

        if let trimmedName, let number, let setCode {
            return "\(trimmedName) \(number) \(setCode)"
        }

        if let trimmedName, let number {
            return "\(trimmedName) \(number)"
        }

        if let trimmedName, let setCode {
            return "\(trimmedName) \(setCode)"
        }

        if let trimmedName {
            return trimmedName
        }

        if let number, number.contains("/"), let setCode {
            return "\(number) \(setCode)"
        }

        if let number, number.contains("/") {
            return number
        }

        return ""
    }

    private func numberCandidates(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var numbers: [String] = []

        let ranked = fields
            .sorted(by: fieldPriority)
            .filter { $0.region == .collectorFooter || isNumberLike($0.text) }

        for field in ranked {
            let allowSimpleNumericToken = field.region != .fullCardFallback
            for token in tokenizeNumberCandidates(field.text) {
                if !allowSimpleNumericToken && !token.contains("/") {
                    continue
                }
                guard seen.insert(token).inserted else { continue }
                numbers.append(token)
                if numbers.count == 4 {
                    return numbers
                }
            }
        }

        return numbers
    }

    private func setCodeCandidates(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var setCodes: [String] = []

        let footerFields = fields
            .sorted(by: fieldPriority)
            .filter { $0.region == .collectorFooter }

        for field in footerFields {
            let tokens: [String]
            tokens = tokensNearCollectorNumber(in: field.text)
            if tokens.isEmpty {
                continue
            }

            for token in tokens {
                let normalized = normalizeAlphaNumeric(token).uppercased()
                guard normalized.count >= 2, normalized.count <= 5 else { continue }
                guard !languageTokens.contains(normalized) else { continue }
                guard !setCodeStopWords.contains(normalized) else { continue }
                guard !isNumberLike(normalized) else { continue }
                guard !noisyBodyKeywords.contains(normalized.lowercased()) else { continue }
                guard !isRarityToken(normalized.lowercased()) else { continue }
                guard looksLikeSetCode(normalized) else { continue }
                guard seen.insert(normalized).inserted else { continue }
                setCodes.append(normalized)
                if setCodes.count == 4 {
                    return setCodes
                }
            }
        }

        if !setCodes.isEmpty {
            return setCodes
        }

        for field in footerFields {
            for token in tokenize(field.text) {
                let normalized = normalizeAlphaNumeric(token).uppercased()
                guard normalized.count >= 2, normalized.count <= 5 else { continue }
                guard !languageTokens.contains(normalized) else { continue }
                guard !setCodeStopWords.contains(normalized) else { continue }
                guard !isNumberLike(normalized) else { continue }
                guard !noisyBodyKeywords.contains(normalized.lowercased()) else { continue }
                guard !isRarityToken(normalized.lowercased()) else { continue }
                guard looksLikeSetCode(normalized) else { continue }
                guard seen.insert(normalized).inserted else { continue }
                setCodes.append(normalized)
                if setCodes.count == 4 {
                    return setCodes
                }
            }
        }

        if !setCodes.isEmpty {
            return setCodes
        }

        let fallbackFields = fields
            .sorted(by: fieldPriority)
            .filter { $0.region == .fullCardFallback }

        for field in fallbackFields {
            let tokens = tokensNearCollectorNumber(in: field.text)
            for token in tokens {
                let normalized = normalizeAlphaNumeric(token).uppercased()
                guard normalized.count >= 2, normalized.count <= 5 else { continue }
                guard !languageTokens.contains(normalized) else { continue }
                guard !setCodeStopWords.contains(normalized) else { continue }
                guard !isNumberLike(normalized) else { continue }
                guard !noisyBodyKeywords.contains(normalized.lowercased()) else { continue }
                guard !isRarityToken(normalized.lowercased()) else { continue }
                guard looksLikeSetCode(normalized) else { continue }
                guard seen.insert(normalized).inserted else { continue }
                setCodes.append(normalized)
                if setCodes.count == 4 {
                    return setCodes
                }
            }
        }

        return setCodes
    }

    private func tokensNearCollectorNumber(in text: String) -> [String] {
        let tokens = tokenize(text)
        guard let collectorIndex = tokens.firstIndex(where: { isNumberLike($0) && $0.contains("/") }) else {
            return []
        }

        let windowStart = max(0, collectorIndex - 3)
        let collectorWindow = tokens[windowStart ..< collectorIndex]
        return Array(collectorWindow)
    }

    private func rarityCandidates(from fields: [RecognizedCardField]) -> [String] {
        let ranked = fields.sorted(by: fieldPriority)
        var seen: Set<String> = []
        var rarities: [String] = []

        let orderedPatterns: [(pattern: String, label: String)] = [
            ("special illustration rare", "Special Illustration Rare"),
            ("illustration rare", "Illustration Rare"),
            ("double rare", "Double Rare"),
            ("ultra rare", "Ultra Rare"),
            ("hyper rare", "Hyper Rare"),
            ("amazing rare", "Amazing Rare"),
            ("holo rare", "Holo Rare"),
            ("uncommon", "Uncommon"),
            ("common", "Common"),
            ("promo", "Promo"),
            ("prism star", "Prism Star"),
            ("rare", "Rare"),
        ]

        for field in ranked {
            let lowercasedText = " \(field.text.lowercased()) "
            for (pattern, label) in orderedPatterns {
                guard lowercasedText.contains(" \(pattern) ") || lowercasedText.contains(pattern + " ") || lowercasedText.contains(" " + pattern) else {
                    continue
                }

                let key = label.lowercased()
                guard seen.insert(key).inserted else { continue }
                rarities.append(label)
                if rarities.count == 4 {
                    return rarities
                }
            }
        }

        return rarities
    }

    private func languageCandidates(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var languages: [String] = []

        for field in fields.sorted(by: fieldPriority) {
            let tokens = tokenize(field.text)
            for token in tokens {
                let normalized = token.uppercased()
                if languageTokens.contains(normalized) {
                    if seen.insert(normalized).inserted {
                        languages.append(normalized)
                    }
                    continue
                }

                switch normalized.lowercased() {
                case "deutsch", "german":
                    if seen.insert("DE").inserted {
                        languages.append("DE")
                    }
                case "english":
                    if seen.insert("EN").inserted {
                        languages.append("EN")
                    }
                default:
                    break
                }
            }
        }

        return languages
    }

    private func rankedFallbackTokens(from fields: [RecognizedCardField]) -> [String] {
        var seen: Set<String> = []
        var tokens: [String] = []

        for field in fields.sorted(by: fieldPriority) {
            if field.region == .attackBox || field.region == .evolutionLine || (field.region == .fullCardFallback && isLikelyBodyNoise(field.text)) {
                continue
            }

            for token in tokenize(field.text) {
                let key = token.lowercased()
                guard !isNoiseToken(key) else { continue }
                guard seen.insert(key).inserted else { continue }
                tokens.append(token)
                if tokens.count == 6 {
                    return tokens
                }
            }
        }

        return tokens
    }

    private func shouldUseFallbackTokens(_ tokens: [String]) -> Bool {
        guard tokens.count >= 2 else {
            return false
        }

        let hasLongLetterToken = tokens.contains { token in
            token.count >= 4 && token.rangeOfCharacter(from: .letters) != nil
        }

        return hasLongLetterToken
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/-")).inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }

    private func tokenizeName(_ text: String) -> [String] {
        tokenize(text)
            .filter { token in
                let lowered = token.lowercased()
                guard !isNumberLike(token) else { return false }
                guard !isNoiseToken(lowered) else { return false }
                guard !isRarityToken(lowered) else { return false }
                return true
            }
    }

    private func tokenizeNumberCandidates(_ text: String) -> [String] {
        tokenize(text)
            .map { normalizeNumericOCR($0, strictNumeric: true).uppercased() }
            .filter(isNumberLike)
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeAlphaNumeric(_ text: String) -> String {
        text.replacingOccurrences(of: "[^A-Za-z0-9]", with: "", options: .regularExpression)
    }

    private func normalizeNumericOCR(_ text: String, strictNumeric: Bool) -> String {
        let shouldMapBToEight = strictNumeric && (text.contains(where: \Character.isNumber) || text.contains("/"))

        return String(text.map { character in
            switch character {
            case "O", "o":
                return "0"
            case "I", "l", "|", "!":
                return "1"
            case "S", "s":
                return "5"
            case "B" where shouldMapBToEight:
                return "8"
            default:
                return character
            }
        })
    }

    private func isNumberLike(_ text: String) -> Bool {
        let normalized = normalizeNumericOCR(text, strictNumeric: true).uppercased()

        if normalized.range(of: "^[0-9]{1,4}$", options: .regularExpression) != nil {
            return true
        }

        if normalized.range(of: "^[A-Z0-9]{1,4}/[A-Z0-9]{1,4}$", options: .regularExpression) != nil {
            return normalized.contains(where: \Character.isNumber)
        }

        return false
    }

    private func looksLikeSetCode(_ token: String) -> Bool {
        guard token.rangeOfCharacter(from: .letters) != nil else {
            return false
        }

        if token.range(of: "^[A-Z]{2,5}[0-9]{0,2}$", options: .regularExpression) != nil {
            return true
        }

        if token.range(of: "^[A-Z]{1,2}[0-9]{2,3}$", options: .regularExpression) != nil {
            return true
        }

        return false
    }

    private func isRarityToken(_ text: String) -> Bool {
        rarityTokens.contains(text)
    }

    private func isNoiseToken(_ text: String) -> Bool {
        noisyBodyKeywords.contains(text)
    }

    private func isLikelyBodyNoise(_ text: String) -> Bool {
        let tokens = tokenize(text)
        guard tokens.count >= 5 else {
            return false
        }

        let noisyTokenCount = tokens.filter { isNoiseToken($0.lowercased()) }.count
        return noisyTokenCount >= 2
    }

    private func looksLikeNameField(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        if lowercasedText.contains("entwickelt sich aus") || lowercasedText.contains("evolves from") {
            return false
        }

        if hasTrailingAttackDamageValue(text) {
            return false
        }

        let tokens = tokenizeName(text)
        guard !tokens.isEmpty else {
            return false
        }

        guard tokens.count <= 4 else {
            return false
        }

        guard tokens.contains(where: { $0.rangeOfCharacter(from: .letters) != nil }) else {
            return false
        }

        let uiNoiseCount = tokens.filter { uiNoiseNameTokens.contains($0.lowercased()) }.count
        guard uiNoiseCount == 0 else {
            return false
        }

        let sentenceStopWordCount = tokens.filter { nameSentenceStopWords.contains($0.lowercased()) }.count
        if sentenceStopWordCount >= 2 {
            return false
        }

        if tokens.count == 1, let token = tokens.first {
            let digitCount = token.filter(\.isNumber).count
            if token.first?.isNumber == true || digitCount >= 2 {
                return false
            }
        }

        return true
    }

    private func hasTrailingAttackDamageValue(_ text: String) -> Bool {
        let normalized = normalizeWhitespace(text)
        let parts = normalized.split(separator: " ")
        guard parts.count >= 2, let last = parts.last else {
            return false
        }

        guard String(last).range(of: "^[0-9]{2,3}$", options: .regularExpression) != nil else {
            return false
        }

        let hasCollectorNumber = parts.contains(where: { $0.contains("/") })
        return !hasCollectorNumber
    }

    private func looksLikeFallbackNameField(_ text: String) -> Bool {
        guard looksLikeNameField(text) else {
            return false
        }

        let tokens = tokenizeName(text)
        let lowered = tokens.map { $0.lowercased() }
        guard !lowered.contains(where: { fallbackNameStopWords.contains($0) }) else {
            return false
        }

        guard tokens.count > 1 else {
            return true
        }

        let titleLikeCount = tokens.filter { token in
            let loweredToken = token.lowercased()
            if nameSuffixTokens.contains(loweredToken) {
                return true
            }
            if token == token.uppercased() {
                return true
            }
            return token.first?.isUppercase == true
        }.count

        return Double(titleLikeCount) / Double(tokens.count) >= 0.5
    }

    private func fieldPriority(_ lhs: RecognizedCardField, _ rhs: RecognizedCardField) -> Bool {
        let rank: [ScanOCRRegion: Int] = [
            .titleStrip: 6,
            .collectorFooter: 5,
            .evolutionLine: 2,
            .attackBox: 1,
            .fullCardFallback: 0,
        ]
        let lhsRank = rank[lhs.region, default: 0]
        let rhsRank = rank[rhs.region, default: 0]
        if lhsRank != rhsRank {
            return lhsRank > rhsRank
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        return lhs.text.count > rhs.text.count
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
