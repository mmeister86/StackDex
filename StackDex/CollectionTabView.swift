import SwiftUI
import SwiftData

struct CollectionTabView: View {
    @Binding var selectedTab: ContentView.RootTab

    @Environment(\.modelContext) private var modelContext
    @Query private var allCollections: [CollectionEntity]

    @State private var scope: CollectionScope = .allCollections
    @State private var searchText: String = ""
    @State private var initializedScope = false

    var body: some View {
        NavigationStack {
            Group {
                if collections.isEmpty {
                    EmptyCollectionStateView(selectedTab: $selectedTab)
                } else {
                    scopedContent
                }
            }
            .navigationTitle("Sammlung")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Alle Sammlungen") {
                            scope = .allCollections
                        }

                        Divider()

                        ForEach(collections) { collection in
                            Button {
                                openCollection(collection)
                            } label: {
                                if isPinnedCollection(collection.id) {
                                    Label(collection.name, systemImage: "pin.fill")
                                } else {
                                    Text(collection.name)
                                }
                            }
                        }
                    } label: {
                        Label(switcherTitle, systemImage: "chevron.up.chevron.down")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Karten suchen")
            .onAppear {
                reconcileSelectionAndScopeIfNeeded()
            }
            .onChange(of: collections.map(\.id)) { _, _ in
                reconcileSelectionAndScopeIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var scopedContent: some View {
        switch scope {
        case .allCollections:
            AllCollectionsOverviewView(collections: collections) { collection in
                openCollection(collection)
            }
        case .collection(let collectionID):
            if let collection = collections.first(where: { $0.id == collectionID }) {
                let visibleStacks = visibleStacks(in: collection)
                if visibleStacks.isEmpty {
                    EmptyCollectionStateView(selectedTab: $selectedTab)
                } else {
                    List(visibleStacks, id: \.id) { stack in
                        NavigationLink {
                            StackDetailView(stack: stack)
                        } label: {
                            CollectionStackRowView(stack: stack)
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                EmptyCollectionStateView(selectedTab: $selectedTab)
            }
        }
    }

    private var switcherTitle: String {
        switch scope {
        case .allCollections:
            return "Alle Sammlungen"
        case .collection(let id):
            return collections.first(where: { $0.id == id })?.name ?? "Sammlung"
        }
    }

    private var collections: [CollectionEntity] {
        allCollections.sorted {
            if $0.lastUsedAt != $1.lastUsedAt {
                return $0.lastUsedAt > $1.lastUsedAt
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func visibleStacks(in collection: CollectionEntity) -> [CardStackEntity] {
        let records = collection.cardStacks.map {
            CollectionSearchEngine.Record(
                stackID: $0.id,
                cardName: $0.cardName,
                setName: $0.setName,
                cardNumber: $0.cardNumber,
                updatedAt: $0.updatedAt
            )
        }
        let orderedIDs = CollectionSearchEngine.filterAndSort(records: records, query: searchText).map(\.stackID)
        let stackByID = Dictionary(uniqueKeysWithValues: collection.cardStacks.map { ($0.id, $0) })
        return orderedIDs.compactMap { stackByID[$0] }
    }

    private func openCollection(_ collection: CollectionEntity) {
        scope = .collection(collection.id)
        collection.lastUsedAt = .now
        AppStateAccess.setActiveCollectionID(collection.id, in: modelContext)
        try? modelContext.save()
    }

    private func isPinnedCollection(_ collectionID: UUID) -> Bool {
        AppStateAccess.primary(in: modelContext).pinnedDefaultCollectionID == collectionID
    }

    private func reconcileSelectionAndScopeIfNeeded() {
        let state = AppStateAccess.primary(in: modelContext)
        let existingIDs = collections.map(\.id)

        let resolved = CollectionSelectionPolicy.resolve(
            state: .init(
                activeCollectionID: state.activeCollectionID,
                pinnedDefaultCollectionID: state.pinnedDefaultCollectionID
            ),
            existingCollectionIDs: existingIDs
        )
        let openingCollectionID = CollectionSelectionPolicy.collectionIDForOpening(
            state: .init(
                activeCollectionID: resolved.activeCollectionID,
                pinnedDefaultCollectionID: resolved.pinnedDefaultCollectionID
            ),
            existingCollectionIDs: existingIDs
        )

        let persistedActive = openingCollectionID
        if state.activeCollectionID != persistedActive || state.pinnedDefaultCollectionID != resolved.pinnedDefaultCollectionID {
            state.activeCollectionID = persistedActive
            state.pinnedDefaultCollectionID = resolved.pinnedDefaultCollectionID
            try? modelContext.save()
        }

        if !initializedScope {
            initializedScope = true
            if let openingCollectionID {
                scope = .collection(openingCollectionID)
            } else {
                scope = .allCollections
            }
            return
        }

        if case .collection(let scopedID) = scope, !existingIDs.contains(scopedID) {
            scope = openingCollectionID.map(CollectionScope.collection) ?? .allCollections
        }
    }
}

private struct CollectionStackRowView: View {
    let stack: CardStackEntity

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.12))
                .frame(width: 44, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(stack.cardName)
                    .font(.headline)
                    .lineLimit(1)

                Text(secondaryLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("x\(stack.totalQuantity)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var secondaryLine: String {
        let set = stack.setName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = stack.cardNumber?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (set, number) {
        case let (.some(setName), .some(cardNumber)) where !setName.isEmpty && !cardNumber.isEmpty:
            return "\(setName) • #\(cardNumber)"
        case let (.some(setName), _ ) where !setName.isEmpty:
            return setName
        case let (_, .some(cardNumber)) where !cardNumber.isEmpty:
            return "#\(cardNumber)"
        default:
            return "Ohne Set-Info"
        }
    }
}

private struct EmptyCollectionStateView: View {
    @Binding var selectedTab: ContentView.RootTab

    var body: some View {
        ContentUnavailableView {
            Label("Noch keine Karten", systemImage: "square.stack.3d.up.slash")
        } description: {
            Text("Scanne eine Karte oder starte mit der manuellen Suche.")
        } actions: {
            Button("Karte scannen") {
                selectedTab = .scan
            }
            .buttonStyle(.borderedProminent)

            Button("Manuell suchen") {
                selectedTab = .scan
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct AllCollectionsOverviewView: View {
    let collections: [CollectionEntity]
    var onOpenCollection: (CollectionEntity) -> Void

    private let grid = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(collections) { collection in
                    Button {
                        onOpenCollection(collection)
                    } label: {
                        CollectionTileView(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}

private struct CollectionTileView: View {
    let collection: CollectionEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.secondary.opacity(0.12))
                .frame(height: 140)
                .overlay {
                    if let urlString = collection.topCardImageURLString,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            placeholder
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        placeholder
                    }
                }

            Text(collection.name)
                .font(.headline)
                .lineLimit(1)

            Text(valueText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(collection.totalCardCount) Karten")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .strokeBorder(.secondary.opacity(0.2))
        )
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Vorschau")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var valueText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .autoupdatingCurrent
        let value = formatter.string(from: collection.totalEstimatedValue as NSDecimalNumber) ?? "-"
        if collection.cardStacks.contains(where: { $0.valuationSummary.isIncomplete }) {
            return "\(value) (teilweise)"
        }
        return value
    }
}
