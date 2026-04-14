//
//  StackDexApp.swift
//  StackDex
//
//  Created by Matthias Meister on 12.04.26.
//

import SwiftUI
import SwiftData

@main
struct StackDexApp: App {
    private static let inMemoryUITestFlag = "-uitest-in-memory"
    private static let seedCollectionUITestFlag = "-uitest-seed-collection"

    var sharedModelContainer: ModelContainer = {
        let isUITestInMemory = ProcessInfo.processInfo.arguments.contains(inMemoryUITestFlag)
        let schema = Schema([
            AppStateEntity.self,
            CollectionEntity.self,
            CardStackEntity.self,
            ConditionBucketEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITestInMemory)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if ProcessInfo.processInfo.arguments.contains(seedCollectionUITestFlag) {
                seedUITestCollectionIfNeeded(in: container)
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }

    private static func seedUITestCollectionIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CollectionEntity>()
        let existingCollections = (try? context.fetch(descriptor)) ?? []
        guard existingCollections.isEmpty else {
            return
        }

        let collection = CollectionEntity(
            name: "UI Seed",
            collectionDescription: nil,
            createdAt: .now,
            updatedAt: .now,
            lastUsedAt: .now
        )
        context.insert(collection)

        let appState = AppStateAccess.primary(in: context)
        appState.activeCollectionID = collection.id
        appState.pinnedDefaultCollectionID = collection.id

        try? context.save()
    }
}
