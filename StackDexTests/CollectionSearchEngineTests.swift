import Foundation
import Testing
@testable import StackDex

struct CollectionSearchEngineTests {
    @Test func emptyQueryReturnsAllRecordsSortedByUpdatedAtDescending() {
        let first = CollectionSearchEngine.Record(
            stackID: UUID(),
            cardName: "Pikachu",
            setName: "Base",
            cardNumber: "58",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let second = CollectionSearchEngine.Record(
            stackID: UUID(),
            cardName: "Bulbasaur",
            setName: "Base",
            cardNumber: "44",
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        let result = CollectionSearchEngine.filterAndSort(records: [first, second], query: "  ")

        #expect(result.map(\.stackID) == [second.stackID, first.stackID])
    }

    @Test func queryMatchesCardNameSetAndNumberCaseAndDiacriticInsensitive() {
        let cardNameRecord = CollectionSearchEngine.Record(
            stackID: UUID(),
            cardName: "Flabebe",
            setName: "Paradox Rift",
            cardNumber: "111",
            updatedAt: Date(timeIntervalSince1970: 30)
        )
        let setRecord = CollectionSearchEngine.Record(
            stackID: UUID(),
            cardName: "Mew",
            setName: "Crown Zenith",
            cardNumber: "001",
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let numberRecord = CollectionSearchEngine.Record(
            stackID: UUID(),
            cardName: "Eevee",
            setName: "Jungle",
            cardNumber: "007",
            updatedAt: Date(timeIntervalSince1970: 10)
        )

        let byName = CollectionSearchEngine.filterAndSort(records: [cardNameRecord, setRecord, numberRecord], query: "flab\u{00E9}b\u{00E9}")
        #expect(byName.map(\.stackID) == [cardNameRecord.stackID])

        let bySet = CollectionSearchEngine.filterAndSort(records: [cardNameRecord, setRecord, numberRecord], query: "crown")
        #expect(bySet.map(\.stackID) == [setRecord.stackID])

        let byNumber = CollectionSearchEngine.filterAndSort(records: [cardNameRecord, setRecord, numberRecord], query: "007")
        #expect(byNumber.map(\.stackID) == [numberRecord.stackID])
    }
}
