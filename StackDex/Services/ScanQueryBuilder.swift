import CoreGraphics
import Foundation

private enum NameSignalStrength {
    case strong
    case weak
}

private struct NameSignal {
    let text: String
    let strength: NameSignalStrength
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
        "ZUGES",
        "VIELE",
        "BORA",
        "INC",
        "SET",
        "CARD",
        "CARDSET",
        "CARDSET?",
        "POKEMON",
        "EN",
        "DE",
        "NOT",
        "ARE",
        "THIS",
        "THAT",
        "WAS",
        "WILL",
        "FROM",
        "WITH",
        "YOUR",
        "YOU",
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

        let preferredNameSignal = preferredName(from: cleanedFields)
        let possibleNumbers = numberCandidates(from: cleanedFields)
        let setCodeResult = setCodeCandidates(from: cleanedFields)
        let possibleSetCodes = setCodeResult.setCodes
        let possibleRarities = rarityCandidates(from: cleanedFields)
        let possibleLanguages = languageCandidates(from: cleanedFields)

        let preferredName = preferredNameSignal?.strength == .strong
            ? canonicalPreferredName(from: preferredNameSignal?.text)
            : nil
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

        let signalQuality = ScanSignalQuality(
            isWeakNameSignal: preferredNameSignal?.strength == .weak,
            hasCollectorNumberSignal: possibleNumbers.contains(where: { $0.contains("/") }),
            hasSuspiciousSetCodes: setCodeResult.hasSuspiciousSetCodes
        )

        return ScanLookupHints(
            normalizedQuery: normalizedQuery,
            nameTokens: nameTokens,
            possibleNumbers: possibleNumbers,
            possibleSetCodes: possibleSetCodes,
            possibleRarities: possibleRarities,
            possibleLanguages: possibleLanguages,
            signalQuality: signalQuality
        )
    }

    private func preferredName(from fields: [RecognizedCardField]) -> NameSignal? {
        let titleStripCandidates = fields
            .filter { $0.region == .titleStrip }
            .sorted(by: fieldPriority)
            .compactMap { field -> NameSignal? in
                guard let strength = evaluateNameSignal(for: field) else {
                    return nil
                }
                return NameSignal(text: field.text, strength: strength)
            }

        if let strong = titleStripCandidates.first(where: { $0.strength == .strong }) {
            return strong
        }

        return titleStripCandidates.first(where: { $0.strength == .weak })
    }

    private func canonicalPreferredName(from preferredName: String?) -> String? {
        guard let preferredName = preferredName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty else {
            return nil
        }

        return PokemonNameCanonicalizer.canonicalize(preferredName, suffixTokens: nameSuffixTokens)
            ?? preferredName
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

        if let number, number.contains("/") {
            if let setCode {
                return "\(number) \(setCode)"
            }
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

    private func setCodeCandidates(from fields: [RecognizedCardField]) -> (setCodes: [String], hasSuspiciousSetCodes: Bool) {
        var seen: Set<String> = []
        var setCodes: [String] = []
        var hasSuspiciousSetCodes = false

        let footerFields = fields
            .sorted(by: fieldPriority)
            .filter { $0.region == .collectorFooter }

        for field in footerFields {
            let extraction = parseSetCodeCandidates(
                from: field.text,
                allowLanguageInterveningTokens: false,
                seen: &seen,
                maxCount: 4
            )
            if extraction.hasSuspiciousSetCodes {
                hasSuspiciousSetCodes = true
            }
            setCodes.append(contentsOf: extraction.setCodes)
            if setCodes.count == 4 {
                return (Array(setCodes.prefix(4)), hasSuspiciousSetCodes)
            }
        }

        if !setCodes.isEmpty {
            return (Array(setCodes.prefix(4)), hasSuspiciousSetCodes)
        }

        for field in footerFields {
            let extraction = parseSetCodeCandidates(
                from: field.text,
                allowLanguageInterveningTokens: true,
                seen: &seen,
                maxCount: 4
            )
            if extraction.hasSuspiciousSetCodes {
                hasSuspiciousSetCodes = true
            }
            setCodes.append(contentsOf: extraction.setCodes)
            if setCodes.count == 4 {
                return (Array(setCodes.prefix(4)), hasSuspiciousSetCodes)
            }
        }

        if !setCodes.isEmpty {
            return (Array(setCodes.prefix(4)), hasSuspiciousSetCodes)
        }

        let fallbackFields = fields
            .sorted(by: fieldPriority)
            .filter { $0.region == .fullCardFallback }

        for field in fallbackFields {
            let extraction = parseSetCodeCandidates(
                from: field.text,
                allowLanguageInterveningTokens: true,
                seen: &seen,
                maxCount: 4 - setCodes.count
            )
            if extraction.hasSuspiciousSetCodes {
                hasSuspiciousSetCodes = true
            }
            setCodes.append(contentsOf: extraction.setCodes)
            if setCodes.count == 4 {
                break
            }
        }

        return (Array(setCodes.prefix(4)), hasSuspiciousSetCodes)
    }

    private func parseSetCodeCandidates(
        from text: String,
        allowLanguageInterveningTokens: Bool,
        seen: inout Set<String>,
        maxCount: Int
    ) -> (setCodes: [String], hasSuspiciousSetCodes: Bool) {
        let tokens = tokenize(text)
        guard let collectorIndex = collectorIndex(in: tokens), collectorIndex > 0 else {
            return ([], false)
        }

        var setCodes: [String] = []
        var hasSuspiciousSetCodes = false
        var examinedCandidateCount = 0

        for index in stride(from: collectorIndex - 1, through: 0, by: -1) {
            if examinedCandidateCount >= 1 {
                break
            }

            let token = tokens[index]
            let normalized = normalizeAlphaNumeric(token).uppercased()
            guard !normalized.isEmpty else { continue }

            if isLanguageToken(normalized) && allowLanguageInterveningTokens {
                continue
            }

            examinedCandidateCount += 1

            let rawToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            if isSetCodeCandidate(
                rawToken: rawToken,
                normalizedToken: normalized,
                seen: &seen,
                setCodes: &setCodes
            ) {
                if setCodes.count == maxCount {
                    break
                }
                continue
            }

            if isPotentialSetCodeNoise(rawToken: rawToken, normalizedToken: normalized) {
                hasSuspiciousSetCodes = true
            }
        }

        return (setCodes, hasSuspiciousSetCodes)
    }

    private func collectorIndex(in tokens: [String]) -> Int? {
        tokens.firstIndex(where: { isNumberLike($0) && $0.contains("/") })
    }

    private func isLanguageToken(_ token: String) -> Bool {
        languageTokens.contains(token) || token == token.uppercased() && token.count == 2 && token.allSatisfy(\.isLetter) && (
            token == "DE" || token == "EN"
        )
    }

    private func isSetCodeCandidate(
        rawToken: String,
        normalizedToken: String,
        seen: inout Set<String>,
        setCodes: inout [String]
    ) -> Bool {
        guard isPotentialSetCodeCandidate(rawToken: rawToken, normalizedToken: normalizedToken) else {
            return false
        }
        guard normalizedToken.count >= 2, normalizedToken.count <= 4 else {
            return false
        }
        guard !languageTokens.contains(normalizedToken) else {
            return false
        }
        guard !setCodeStopWords.contains(normalizedToken) else {
            return false
        }
        guard !isNumberLike(normalizedToken) else {
            return false
        }
        guard !noisyBodyKeywords.contains(normalizedToken.lowercased()) else {
            return false
        }
        guard !isRarityToken(normalizedToken.lowercased()) else {
            return false
        }
        guard looksLikeSetCode(normalizedToken) else {
            return false
        }
        guard seen.insert(normalizedToken).inserted else {
            return false
        }

        setCodes.append(normalizedToken)
        return true
    }

    private func isPotentialSetCodeCandidate(rawToken: String, normalizedToken: String) -> Bool {
        guard normalizedToken == rawToken.uppercased() else {
            return false
        }
        guard normalizedToken.range(of: "^[A-Z0-9]+$", options: .regularExpression) != nil else {
            return false
        }
        return true
    }

    private func isPotentialSetCodeNoise(rawToken: String, normalizedToken: String) -> Bool {
        guard isPotentialSetCodeCandidate(rawToken: rawToken, normalizedToken: normalizedToken) else {
            return false
        }
        guard normalizedToken.count >= 2, normalizedToken.count <= 4 else {
            return false
        }
        guard !isRarityToken(normalizedToken.lowercased()) else {
            return false
        }
        guard !languageTokens.contains(normalizedToken) else {
            return false
        }
        return true
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
            return true
        }

        return false
    }

    private func looksLikeSetCode(_ token: String) -> Bool {
        if token.range(of: "^(?=.*[A-Z])[A-Z0-9]{2,4}$", options: .regularExpression) != nil {
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

    private func evaluateNameSignal(for field: RecognizedCardField) -> NameSignalStrength? {
        guard isLikelyNameField(field.text) else {
            return nil
        }

        let tokens = tokenizeName(field.text)
        guard !tokens.isEmpty else {
            return nil
        }

        guard tokens.count <= 4 else {
            return nil
        }

        guard tokens.contains(where: { $0.rangeOfCharacter(from: .letters) != nil }) else {
            return nil
        }

        if tokens.count == 1, let token = tokens.first {
            let digitCount = token.filter(\.isNumber).count
            if token.first?.isNumber == true || digitCount >= 2 {
                return nil
            }

            guard token.count <= 3 else {
                return field.boundingBox.width >= 0.16 ? .strong : nil
            }

            if field.boundingBox.width >= 0.22 && field.confidence >= 0.85 {
                return .strong
            }

            return .weak
        }

        if field.boundingBox.width < 0.16 {
            return nil
        }

        return .strong
    }

    private func isLikelyNameField(_ text: String) -> Bool {
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
        guard isLikelyNameField(text) else {
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
