import Foundation

struct AppConfiguration {
    static let defaultConvexURLString = "https://backend.stackdex.de"
    static let defaultConvexLookupPath = "cards:lookup"
    static let defaultConvexLookupSchemaVersion = "cards.lookup.v1"

    static let convexURLInfoKey = "STACKDEX_CONVEX_URL"
    static let convexLookupPathInfoKey = "STACKDEX_CONVEX_LOOKUP_PATH"
    static let convexLookupSchemaVersionInfoKey = "STACKDEX_CONVEX_LOOKUP_SCHEMA_VERSION"

    let convexBaseURL: URL
    let convexLookupPath: String
    let convexLookupSchemaVersion: String

    init(bundle: Bundle = .main) {
        let rawURL = bundle.stringValue(forInfoDictionaryKey: Self.convexURLInfoKey)
            ?? Self.defaultConvexURLString
        let resolvedURL = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? URL(string: Self.defaultConvexURLString)
            ?? URL(string: "https://backend.stackdex.de")!

        let rawLookupPath = bundle.stringValue(forInfoDictionaryKey: Self.convexLookupPathInfoKey)
            ?? Self.defaultConvexLookupPath
        let resolvedLookupPath = rawLookupPath.trimmingCharacters(in: .whitespacesAndNewlines)

        let rawSchemaVersion = bundle.stringValue(forInfoDictionaryKey: Self.convexLookupSchemaVersionInfoKey)
            ?? Self.defaultConvexLookupSchemaVersion
        let resolvedSchemaVersion = rawSchemaVersion.trimmingCharacters(in: .whitespacesAndNewlines)

        self.convexBaseURL = resolvedURL
        self.convexLookupPath = resolvedLookupPath.isEmpty ? Self.defaultConvexLookupPath : resolvedLookupPath
        self.convexLookupSchemaVersion = resolvedSchemaVersion.isEmpty
            ? Self.defaultConvexLookupSchemaVersion
            : resolvedSchemaVersion
    }
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) else {
            return nil
        }
        return value as? String
    }
}

struct CardLookupRequest {
    let recognizedTexts: [String]
    let hints: ScanLookupHints?
    let maxResults: Int

    init(recognizedTexts: [String], hints: ScanLookupHints? = nil, maxResults: Int = 3) {
        self.recognizedTexts = recognizedTexts
        self.hints = hints
        self.maxResults = max(1, maxResults)
    }
}

protocol CardLookupServing {
    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate]
}

extension CardLookupServing {
    func lookupCandidates(from recognizedTexts: [String], maxResults: Int) async -> [CardLookupCandidate] {
        await lookupCandidates(for: CardLookupRequest(recognizedTexts: recognizedTexts, maxResults: maxResults))
    }
}

struct CardLookupCandidate: Identifiable, Hashable, Sendable {
    struct Details: Hashable, Sendable {
        let rarity: String?
        let setCode: String?
    }

    let id: String
    let identity: CardIdentity
    let imageURLString: String?
    let generalPrice: Decimal?
    let details: Details?
    let conditionPrices: [CardCondition: Decimal]
    let confidence: Double

    init(
        identity: CardIdentity,
        imageURLString: String? = nil,
        generalPrice: Decimal? = nil,
        details: Details? = nil,
        conditionPrices: [CardCondition: Decimal] = [:],
        confidence: Double
    ) {
        self.id = identity.canonicalCardID
        self.identity = identity
        self.imageURLString = imageURLString
        self.generalPrice = generalPrice
        self.details = details
        self.conditionPrices = conditionPrices
        self.confidence = confidence
    }
}

struct MockCardLookupService: CardLookupServing {
    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate] {
        let recognizedSource = request.recognizedTexts.joined(separator: " ").lowercased()
        let hintedSource = request.hints?.normalizedQuery.lowercased() ?? ""
        let source = [recognizedSource, hintedSource]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let allCandidates: [CardLookupCandidate] = [
            .init(
                identity: CardIdentity(canonicalCardID: "sv2-199", name: "Pikachu", setName: "Paldea Evolved", cardNumber: "199"),
                generalPrice: Decimal(string: "14.5"),
                confidence: source.contains("pikachu") ? 0.91 : 0.64
            ),
            .init(
                identity: CardIdentity(canonicalCardID: "sv3-151", name: "Charizard ex", setName: "151", cardNumber: "006"),
                generalPrice: Decimal(string: "38"),
                confidence: source.contains("char") ? 0.87 : 0.53
            ),
            .init(
                identity: CardIdentity(canonicalCardID: "swsh1-032", name: "Sobble", setName: "Sword & Shield", cardNumber: "032"),
                generalPrice: Decimal(string: "1.2"),
                confidence: source.contains("sobble") ? 0.84 : 0.42
            ),
        ]

        let sorted = allCandidates.sorted(by: { $0.confidence > $1.confidence })
        let positiveMatches = sorted.filter { candidate in
            source.contains(candidate.identity.name.lowercased().split(separator: " ").first ?? "") || candidate.confidence >= 0.6
        }
        return Array(positiveMatches.prefix(request.maxResults))
    }
}

struct ConvexPreferredCardLookupService: CardLookupServing {
    let primary: ConvexCardLookupService
    let fallback: any CardLookupServing

    init(primary: ConvexCardLookupService, fallback: any CardLookupServing = MockCardLookupService()) {
        self.primary = primary
        self.fallback = fallback
    }

    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate] {
        do {
            return try await primary.lookupCandidatesThrowing(for: request)
        } catch {
            return await fallback.lookupCandidates(for: request)
        }
    }
}

enum CardLookupServiceFactory {
    static func makeDefault(bundle: Bundle = .main) -> any CardLookupServing {
        if ProcessInfo.processInfo.arguments.contains("-uitest-mock-lookup") {
            return MockCardLookupService()
        }

        let config = AppConfiguration(bundle: bundle)
        let primary = ConvexCardLookupService(
            baseURL: config.convexBaseURL,
            lookupPath: config.convexLookupPath,
            responseSchemaVersion: config.convexLookupSchemaVersion
        )
        return ConvexPreferredCardLookupService(primary: primary)
    }
}

struct ConvexCardLookupService: CardLookupServing {
    let baseURL: URL
    let lookupPath: String
    let responseSchemaVersion: String
    let session: URLSession

    init(
        baseURL: URL,
        lookupPath: String,
        responseSchemaVersion: String = AppConfiguration.defaultConvexLookupSchemaVersion,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.lookupPath = lookupPath
        self.responseSchemaVersion = responseSchemaVersion
        self.session = session
    }

    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate] {
        (try? await lookupCandidatesThrowing(for: request)) ?? []
    }

    func lookupCandidatesThrowing(for request: CardLookupRequest) async throws -> [CardLookupCandidate] {
        let endpoint = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("action")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: convexRequestBody(for: request))

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw ConvexLookupError.invalidHTTPResponse
        }

        let parsedObject = try JSONSerialization.jsonObject(with: data)
        let payloadRoot = Self.resolvedPayloadRoot(from: parsedObject)
        let payload = try validatedPayload(from: payloadRoot)
        let candidates = Self.extractCandidatePayloads(from: payload)
            .compactMap(Self.mapCandidate(from:))
            .sorted(by: { $0.confidence > $1.confidence })

        return Array(candidates.prefix(request.maxResults))
    }

    func convexRequestBody(for request: CardLookupRequest) -> [String: Any] {
        var args: [String: Any] = [
            "recognizedTexts": request.recognizedTexts,
            "query": request.hints?.normalizedQuery ?? request.recognizedTexts.joined(separator: " "),
            "maxResults": request.maxResults,
            "responseSchemaVersion": responseSchemaVersion,
        ]

        if let hints = request.hints {
            args["hints"] = [
                "normalizedQuery": hints.normalizedQuery,
                "nameTokens": hints.nameTokens,
                "possibleNumbers": hints.possibleNumbers,
            ]
        }

        return [
            "path": lookupPath,
            "args": args,
            "format": "json",
        ]
    }

}

extension ConvexCardLookupService {
    enum ConvexLookupError: Error {
        case invalidHTTPResponse
        case emptyResult
        case unsupportedSchemaVersion
    }

    func validatedPayload(from payloadRoot: Any) throws -> Any {
        guard let envelope = payloadRoot as? [String: Any] else {
            return payloadRoot
        }

        let usesPayloadEnvelope = envelope.keys.contains("payload")
        let schemaVersion = Self.firstString(in: envelope, keys: ["schemaVersion"])?.trimmedNonEmpty

        if usesPayloadEnvelope {
            guard let schemaVersion else {
                throw ConvexLookupError.unsupportedSchemaVersion
            }

            guard isSupportedSchemaVersion(schemaVersion) else {
                throw ConvexLookupError.unsupportedSchemaVersion
            }

            if let nestedPayload = envelope["payload"] {
                return nestedPayload
            }
        }

        guard let schemaVersion else {
            return payloadRoot
        }

        guard isSupportedSchemaVersion(schemaVersion) else {
            throw ConvexLookupError.unsupportedSchemaVersion
        }

        if let nestedPayload = envelope["payload"] {
            return nestedPayload
        }

        return payloadRoot
    }

    private func isSupportedSchemaVersion(_ schemaVersion: String) -> Bool {
        schemaVersion == responseSchemaVersion
    }

    static func resolvedPayloadRoot(from parsedObject: Any) -> Any {
        guard let root = parsedObject as? [String: Any] else {
            return parsedObject
        }

        for key in ["value", "result", "data"] {
            if let value = root[key] {
                return value
            }
        }

        return root
    }

    static func extractCandidatePayloads(from payload: Any) -> [[String: Any]] {
        if let direct = payload as? [[String: Any]] {
            return direct
        }

        if let object = payload as? [String: Any] {
            for key in ["results", "candidates", "items", "cards", "matches", "entries", "payload"] {
                if let nested = object[key] {
                    let extracted = extractCandidatePayloads(from: nested)
                    if !extracted.isEmpty {
                        return extracted
                    }
                }
            }

            if firstString(in: object, keys: ["name", "cardName", "title"]) != nil {
                return [object]
            }
        }

        if let array = payload as? [Any] {
            return array.compactMap { $0 as? [String: Any] }
        }

        return []
    }

    static func mapCandidate(from payload: [String: Any]) -> CardLookupCandidate? {
        guard let name = firstString(in: payload, keys: ["name", "cardName", "title"])?.trimmedNonEmpty else {
            return nil
        }

        let setName = firstString(in: payload, keys: ["setName", "set", "set_name", "series", "expansion"])
        let cardNumber = firstString(in: payload, keys: ["cardNumber", "collectorNumber", "number", "no", "setNumber"])

        let canonicalCardID = firstString(
            in: payload,
            keys: ["canonicalCardID", "canonicalCardId", "cardID", "cardId", "id", "_id"]
        ) ?? synthesizedCanonicalID(name: name, setName: setName, cardNumber: cardNumber)

        let imageURLString = firstString(
            in: payload,
            keys: ["imageURLString", "imageUrl", "imageURL", "image", "images.small", "images.large"]
        )

        let generalPrice = decimal(
            from: firstValue(in: payload, keys: ["generalPrice", "price", "marketPrice", "prices.market"])
        )

        let details = mapDetails(from: payload)
        let conditionPrices = mapConditionPrices(from: payload)

        let confidence = min(
            max(double(from: firstValue(in: payload, keys: ["confidence", "score", "relevance", "matchScore"])) ?? 0.5, 0),
            1
        )

        return CardLookupCandidate(
            identity: CardIdentity(
                canonicalCardID: canonicalCardID,
                name: name,
                setName: setName,
                cardNumber: cardNumber
            ),
            imageURLString: imageURLString,
            generalPrice: generalPrice,
            details: details,
            conditionPrices: conditionPrices,
            confidence: confidence
        )
    }

    static func mapDetails(from payload: [String: Any]) -> CardLookupCandidate.Details? {
        let rarity = firstString(in: payload, keys: ["details.rarity", "rarity"])
        let setCode = firstString(in: payload, keys: ["details.setCode", "setCode", "set_code"])

        guard rarity != nil || setCode != nil else {
            return nil
        }

        return CardLookupCandidate.Details(rarity: rarity, setCode: setCode)
    }

    static func mapConditionPrices(from payload: [String: Any]) -> [CardCondition: Decimal] {
        let directConditions = firstValue(in: payload, keys: ["prices.conditions", "conditionPrices", "conditions"])
        if let mapped = mapConditionPriceDictionary(from: directConditions), !mapped.isEmpty {
            return mapped
        }

        if let pricesObject = firstValue(in: payload, keys: ["prices"]) as? [String: Any] {
            let mapped = mapConditionPriceDictionary(from: pricesObject) ?? [:]
            if !mapped.isEmpty {
                return mapped
            }
        }

        return [:]
    }

    static func mapConditionPriceDictionary(from value: Any?) -> [CardCondition: Decimal]? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }

        var mapped: [CardCondition: Decimal] = [:]
        for (rawKey, rawValue) in dictionary {
            guard let condition = cardCondition(from: rawKey) else {
                continue
            }
            guard let price = decimal(from: rawValue) else {
                continue
            }
            mapped[condition] = price
        }
        return mapped
    }

    static func cardCondition(from rawKey: String) -> CardCondition? {
        let normalized = rawKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        if let exact = CardCondition(rawValue: normalized) {
            return exact
        }

        switch normalized {
        case "mintcondition", "mint_card":
            return .mint
        case "nearmint", "nm", "near_mint_condition", "nm_mint":
            return .nearMint
        case "lightlyplayed", "lp", "light_played":
            return .lightlyPlayed
        case "moderatelyplayed", "mp", "moderate_played":
            return .moderatelyPlayed
        case "heavilyplayed", "hp", "heavy_played":
            return .heavilyPlayed
        default:
            return nil
        }
    }

    static func firstValue(in object: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if key.contains(".") {
                let parts = key.split(separator: ".").map(String.init)
                if let nested = value(in: object, path: parts) {
                    return nested
                }
            } else if let value = object[key] {
                return value
            }
        }
        return nil
    }

    static func value(in object: [String: Any], path: [String]) -> Any? {
        guard let first = path.first else {
            return object
        }

        guard let currentValue = object[first] else {
            return nil
        }

        if path.count == 1 {
            return currentValue
        }

        guard let nestedObject = currentValue as? [String: Any] else {
            return nil
        }

        return value(in: nestedObject, path: Array(path.dropFirst()))
    }

    static func firstString(in object: [String: Any], keys: [String]) -> String? {
        guard let value = firstValue(in: object, keys: keys) else {
            return nil
        }

        if let direct = value as? String {
            return direct
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let dictionary = value as? [String: Any], let nested = dictionary["name"] as? String {
            return nested
        }

        return nil
    }

    static func double(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    static func decimal(from value: Any?) -> Decimal? {
        if let number = value as? NSNumber {
            return number.decimalValue
        }
        if let string = value as? String {
            return Decimal(
                string: string.replacingOccurrences(of: ",", with: "."),
                locale: Locale(identifier: "en_US_POSIX")
            )
        }
        return nil
    }

    static func synthesizedCanonicalID(name: String, setName: String?, cardNumber: String?) -> String {
        let nameToken = slug(from: name)
        let setToken = slug(from: setName ?? "unknown")
        let numberToken = slug(from: cardNumber ?? "na")
        return "\(setToken)-\(numberToken)-\(nameToken)"
    }

    static func slug(from value: String) -> String {
        let lowered = value.lowercased()
        let replaced = lowered.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        return replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
