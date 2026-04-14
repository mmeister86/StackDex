import SwiftUI
import SwiftData

struct SettingsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCollections: [CollectionEntity]

    @State private var newCollectionName = ""
    @State private var newCollectionDescription = ""
    @State private var pinnedCollectionID: UUID?

    @State private var collectionToRename: CollectionEntity?
    @State private var renameName: String = ""
    @State private var renameDescription: String = ""

    @State private var collectionToDelete: CollectionEntity?

    var body: some View {
        NavigationStack {
            Form {
                createCollectionSection
                pinnedCollectionSection
                existingCollectionsSection
            }
            .navigationTitle("Einstellungen")
            .onAppear {
                pinnedCollectionID = AppStateAccess.primary(in: modelContext).pinnedDefaultCollectionID
            }
            .onChange(of: collections.map(\.id)) { _, _ in
                pinnedCollectionID = AppStateAccess.primary(in: modelContext).pinnedDefaultCollectionID
            }
            .sheet(item: $collectionToRename) { _ in
                renameSheet
            }
            .alert("Sammlung löschen?", isPresented: Binding(
                get: { collectionToDelete != nil },
                set: { isPresented in
                    if !isPresented {
                        collectionToDelete = nil
                    }
                }
            )) {
                Button("Löschen", role: .destructive) {
                    if let collectionToDelete {
                        delete(collectionToDelete)
                    }
                    collectionToDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    collectionToDelete = nil
                }
            } message: {
                Text("Diese Aktion entfernt die Sammlung und alle enthaltenen Stapel.")
            }
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

    private var createCollectionSection: some View {
        Section("Sammlung erstellen") {
            TextField("Name", text: $newCollectionName)
                .accessibilityIdentifier("settings.create.name")
            TextField("Beschreibung (optional)", text: $newCollectionDescription)
                .accessibilityIdentifier("settings.create.description")

            Button("Erstellen") {
                createCollection()
            }
            .accessibilityIdentifier("settings.create.submit")
            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var pinnedCollectionSection: some View {
        Section("Standard-Sammlung") {
            Picker("Angeheftet", selection: $pinnedCollectionID) {
                Text("Keine").tag(nil as UUID?)
                ForEach(collections) { collection in
                    Text(collection.name).tag(Optional(collection.id))
                }
            }
            .accessibilityIdentifier("settings.pinned.picker")
            .onChange(of: pinnedCollectionID) { _, newValue in
                AppStateAccess.setPinnedCollectionID(newValue, in: modelContext)
            }
        }
    }

    private var existingCollectionsSection: some View {
        Section("Sammlungen verwalten") {
            if collections.isEmpty {
                Text("Keine Sammlungen vorhanden.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(collections) { collection in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name)
                            if let description = collection.collectionDescription, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if AppStateAccess.primary(in: modelContext).activeCollectionID == collection.id {
                            Text("Aktiv")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if pinnedCollectionID == collection.id {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.secondary)
                        }

                        Menu {
                            Button("Als aktiv setzen") {
                                AppStateAccess.setActiveCollectionID(collection.id, in: modelContext)
                                collection.lastUsedAt = .now
                                try? modelContext.save()
                            }
                            .accessibilityIdentifier("settings.collection.setActive")

                            Button("Umbenennen") {
                                collectionToRename = collection
                                renameName = collection.name
                                renameDescription = collection.collectionDescription ?? ""
                            }

                            Button("Löschen", role: .destructive) {
                                collectionToDelete = collection
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                        }
                        .accessibilityLabel("Aktionen \(collection.name)")
                    }
                }
            }
        }
    }

    private var renameSheet: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $renameName)
                TextField("Beschreibung (optional)", text: $renameDescription)
            }
            .navigationTitle("Sammlung bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        collectionToRename = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        applyRename()
                    }
                    .disabled(renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func createCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = newCollectionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        let collection = CollectionEntity(
            name: name,
            collectionDescription: description.isEmpty ? nil : description,
            createdAt: .now,
            updatedAt: .now,
            lastUsedAt: .now
        )

        modelContext.insert(collection)

        let activeCollectionID = AppStateAccess.primary(in: modelContext).activeCollectionID
        if activeCollectionID == nil {
            AppStateAccess.setActiveCollectionID(collection.id, in: modelContext)
        }

        try? modelContext.save()

        newCollectionName = ""
        newCollectionDescription = ""
    }

    private func applyRename() {
        guard let collectionToRename else {
            return
        }

        let name = renameName.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = renameDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        collectionToRename.name = name
        collectionToRename.collectionDescription = description.isEmpty ? nil : description
        collectionToRename.updatedAt = .now

        try? modelContext.save()
        self.collectionToRename = nil
    }

    private func delete(_ collection: CollectionEntity) {
        let remainingCollectionIDs = collections
            .filter { $0.id != collection.id }
            .map(\.id)

        modelContext.delete(collection)
        try? modelContext.save()

        AppStateAccess.resolveAfterDeletion(
            deletedCollectionID: collection.id,
            in: modelContext,
            remainingCollectionIDs: remainingCollectionIDs
        )

        pinnedCollectionID = AppStateAccess.primary(in: modelContext).pinnedDefaultCollectionID
    }
}
