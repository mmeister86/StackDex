import Foundation
import Testing
@testable import StackDex

@Suite(.serialized)
struct ConvexCardLookupServiceTests {
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
              "imageUrl": "https://img.example/pikachu.png",
              "price": "19,95",
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
                "prices": { "market": 350.2 },
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
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
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
