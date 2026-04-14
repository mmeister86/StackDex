import Foundation
import Testing
@testable import StackDex

@Suite(.serialized)
struct ConvexCardLookupServiceTests {
    @Test func mapsNmMintAliasToNearMintCondition() {
        let mapped = ConvexCardLookupService.cardCondition(from: "nm_mint")

        #expect(mapped == .nearMint)
    }

    @Test func mapsConvexValueArrayToCardCandidates() async throws {
        let payload = """
        {
          "status": "success",
          "value": [
            {
              "canonicalCardId": "sv8-123",
              "name": "Pikachu ex",
              "set": { "name": "Surging Sparks" },
              "number": "123",
              "details": {
                "rarity": "Illustration Rare",
                "setCode": "SV8"
              },
              "imageUrl": "https://img.example/pikachu.png",
              "price": "19,95",
              "prices": {
                "market": "19,95",
                "conditions": {
                  "near_mint": "22.50",
                  "lightly_played": 18.4,
                  "damaged": "5.00"
                }
              },
              "score": 0.91
            },
            {
              "id": "sv8-122",
              "cardName": "Raichu",
              "setName": "Surging Sparks",
              "collectorNumber": "122",
              "confidence": 0.75
            }
          ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        let candidates = try await service.lookupCandidatesThrowing(
            for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
        )

        #expect(candidates.count == 2)
        #expect(candidates.map(\.id) == ["sv8-123", "sv8-122"])
        #expect(candidates[0].identity.setName == "Surging Sparks")
        #expect(candidates[0].identity.cardNumber == "123")
        #expect(candidates[0].imageURLString == "https://img.example/pikachu.png")
        #expect(candidates[0].generalPrice == Decimal(string: "19.95"))
        #expect(candidates[0].confidence == 0.91)
        #expect(candidates[0].details?.rarity == "Illustration Rare")
        #expect(candidates[0].details?.setCode == "SV8")
        #expect(candidates[0].conditionPrices[.nearMint] == Decimal(string: "22.50"))
        #expect(candidates[0].conditionPrices[.lightlyPlayed] == Decimal(string: "18.4"))
        #expect(candidates[0].conditionPrices[.damaged] == Decimal(string: "5.00"))

        #expect(candidates[1].identity.name == "Raichu")
        #expect(candidates[1].identity.setName == "Surging Sparks")
        #expect(candidates[1].identity.cardNumber == "122")
        #expect(candidates[1].generalPrice == nil)
        #expect(candidates[1].confidence == 0.75)
    }

    @Test func mapsNestedConvexPayloadAndSynthesizesID() async throws {
        let payload = """
        {
          "result": {
            "candidates": [
              {
                "title": "Charizard",
                "set": "Base Set",
                "cardNumber": "4",
                "details": {
                  "rarity": "Holo Rare",
                  "setCode": "BS"
                },
                "prices": {
                  "market": 350.2,
                  "conditions": {
                    "mint": 800,
                    "moderately_played": "240.00"
                  }
                },
                "relevance": 0.87
              }
            ]
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        let candidates = try await service.lookupCandidatesThrowing(
            for: CardLookupRequest(recognizedTexts: ["charizard"], maxResults: 3)
        )

        #expect(candidates.count == 1)
        #expect(candidates[0].id == "base-set-4-charizard")
        #expect(candidates[0].generalPrice == Decimal(string: "350.2"))
        #expect(candidates[0].confidence == 0.87)
        #expect(candidates[0].details?.rarity == "Holo Rare")
        #expect(candidates[0].details?.setCode == "BS")
        #expect(candidates[0].conditionPrices[.mint] == Decimal(string: "800"))
        #expect(candidates[0].conditionPrices[.moderatelyPlayed] == Decimal(string: "240.00"))
    }

    @Test func mapsVersionedEnvelopePayloadToCardCandidates() async throws {
        let payload = """
        {
          "value": {
            "schemaVersion": "cards.lookup.v1",
            "payload": {
              "candidates": [
                {
                  "canonicalCardId": "sv8-123",
                  "name": "Pikachu ex",
                  "set": { "name": "Surging Sparks" },
                  "number": "123",
                  "details": {
                    "rarity": "Illustration Rare",
                    "setCode": "SV8"
                  },
                  "imageUrl": "https://img.example/pikachu.png",
                  "prices": {
                    "market": "19,95",
                    "conditions": {
                      "near_mint": "22.50",
                      "lightly_played": 18.4,
                      "damaged": "5.00"
                    }
                  },
                  "score": 0.91
                }
              ]
            }
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        let candidates = try await service.lookupCandidatesThrowing(
            for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
        )

        #expect(candidates.count == 1)
        #expect(candidates[0].id == "sv8-123")
        #expect(candidates[0].identity.name == "Pikachu ex")
        #expect(candidates[0].identity.setName == "Surging Sparks")
        #expect(candidates[0].identity.cardNumber == "123")
        #expect(candidates[0].details?.rarity == "Illustration Rare")
        #expect(candidates[0].details?.setCode == "SV8")
        #expect(candidates[0].generalPrice == Decimal(string: "19.95"))
        #expect(candidates[0].conditionPrices[.nearMint] == Decimal(string: "22.50"))
        #expect(candidates[0].conditionPrices[.lightlyPlayed] == Decimal(string: "18.4"))
        #expect(candidates[0].conditionPrices[.damaged] == Decimal(string: "5.00"))
    }

    @Test func returnsEmptyArrayForVersionedEnvelopeWithEmptyCandidates() async throws {
        let payload = """
        {
          "value": {
            "schemaVersion": "cards.lookup.v1",
            "payload": {
              "candidates": []
            }
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        let candidates = try await service.lookupCandidatesThrowing(
            for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
        )

        #expect(candidates == [])
    }

    @Test func throwsTypedErrorForUnsupportedSchemaVersion() async {
        let payload = """
        {
          "value": {
            "schemaVersion": "cards.lookup.v2",
            "payload": {
              "candidates": [
                {
                  "canonicalCardId": "sv8-123",
                  "name": "Pikachu ex",
                  "setName": "Surging Sparks",
                  "cardNumber": "123",
                  "score": 0.91
                }
              ]
            }
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        do {
            _ = try await service.lookupCandidatesThrowing(
                for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
            )
            Issue.record("Expected unsupported schema version error")
        } catch let error as ConvexCardLookupService.ConvexLookupError {
            guard case .unsupportedSchemaVersion = error else {
                Issue.record("Expected unsupported schema version error, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected ConvexLookupError.unsupportedSchemaVersion, got \(error)")
        }
    }

    @Test func throwsSchemaErrorWhenConfiguredVersionIsV2ButServerReturnsV1() async {
        let payload = """
        {
          "value": {
            "schemaVersion": "cards.lookup.v1",
            "payload": {
              "candidates": [
                {
                  "canonicalCardId": "sv8-123",
                  "name": "Pikachu ex",
                  "setName": "Surging Sparks",
                  "cardNumber": "123",
                  "score": 0.91
                }
              ]
            }
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            responseSchemaVersion: "cards.lookup.v2",
            session: makeSession()
        )

        do {
            _ = try await service.lookupCandidatesThrowing(
                for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
            )
            Issue.record("Expected unsupported schema version error")
        } catch let error as ConvexCardLookupService.ConvexLookupError {
            guard case .unsupportedSchemaVersion = error else {
                Issue.record("Expected unsupported schema version error, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected ConvexLookupError.unsupportedSchemaVersion, got \(error)")
        }
    }

    @Test func throwsSchemaErrorWhenEnvelopePayloadIsMissingSchemaVersion() async {
        let payload = """
        {
          "value": {
            "payload": {
              "candidates": [
                {
                  "canonicalCardId": "sv8-123",
                  "name": "Pikachu ex",
                  "setName": "Surging Sparks",
                  "cardNumber": "123",
                  "score": 0.91
                }
              ]
            }
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        do {
            _ = try await service.lookupCandidatesThrowing(
                for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
            )
            Issue.record("Expected unsupported schema version error")
        } catch let error as ConvexCardLookupService.ConvexLookupError {
            guard case .unsupportedSchemaVersion = error else {
                Issue.record("Expected unsupported schema version error, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected ConvexLookupError.unsupportedSchemaVersion, got \(error)")
        }
    }

    @Test func requestBodyIncludesResponseSchemaVersionHint() throws {
        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup"
        )

        let body = service.convexRequestBody(for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3))
        let args = try #require(body["args"] as? [String: Any])
        let responseSchemaVersion = try #require(args["responseSchemaVersion"] as? String)

        #expect(responseSchemaVersion == "cards.lookup.v1")
    }

    @Test func requestBodyUsesConfiguredResponseSchemaVersionHint() throws {
        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            responseSchemaVersion: "cards.lookup.v2"
        )

        let body = service.convexRequestBody(for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3))
        let args = try #require(body["args"] as? [String: Any])
        let responseSchemaVersion = try #require(args["responseSchemaVersion"] as? String)

        #expect(responseSchemaVersion == "cards.lookup.v2")
    }

    @Test func lookupCallsConvexActionTransportEndpoint() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://backend.stackdex.de/api/action")
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data("{\"value\":[]}".utf8))
        }

        let service = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )

        _ = try await service.lookupCandidatesThrowing(
            for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
        )
    }

    @Test func preferredServiceFallsBackToMockWhenConvexFails() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data())
        }

        let convex = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )
        let fallbackCandidate = CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: "fallback-id", name: "Fallback"),
            confidence: 0.8
        )
        let preferred = ConvexPreferredCardLookupService(
            primary: convex,
            fallback: StubLookupService(candidates: [fallbackCandidate])
        )

        let candidates = await preferred.lookupCandidates(
            for: CardLookupRequest(recognizedTexts: ["fallback"], maxResults: 3)
        )

        #expect(candidates == [fallbackCandidate])
    }

    @Test func preferredServiceDoesNotFallbackWhenPrimaryReturnsEmptySuccess() async {
        let payload = """
        {
          "value": {
            "schemaVersion": "cards.lookup.v1",
            "payload": {
              "candidates": []
            }
          }
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (try #require(response), Data(payload.utf8))
        }

        let convex = ConvexCardLookupService(
            baseURL: URL(string: "https://backend.stackdex.de")!,
            lookupPath: "cards:lookup",
            session: makeSession()
        )
        let fallbackCandidate = CardLookupCandidate(
            identity: CardIdentity(canonicalCardID: "fallback-id", name: "Fallback"),
            confidence: 0.8
        )
        let preferred = ConvexPreferredCardLookupService(
            primary: convex,
            fallback: StubLookupService(candidates: [fallbackCandidate])
        )

        let candidates = await preferred.lookupCandidates(
            for: CardLookupRequest(recognizedTexts: ["pikachu"], maxResults: 3)
        )

        #expect(candidates == [])
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private struct StubLookupService: CardLookupServing {
    let candidates: [CardLookupCandidate]

    func lookupCandidates(for request: CardLookupRequest) async -> [CardLookupCandidate] {
        Array(candidates.prefix(request.maxResults))
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
