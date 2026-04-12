import SwiftUI
import SwiftData

struct StackDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCollections: [CollectionEntity]

    let stack: CardStackEntity

    @State private var showDeleteConfirmation = false
    @State private var destinationCollectionID: UUID?

    var body: some View {
        Form {
            baseInfoSection
            conditionSection
            moveCopySection
            deleteSection
        }
        .navigationTitle(stack.cardName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            destinationCollectionID = availableDestinations.first?.id
        }
        .alert("Stapel wirklich löschen?", isPresented: $showDeleteConfirmation) {
            Button("Löschen", role: .destructive) {
                deleteStack()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Diese Aktion entfernt den gesamten Stapel dauerhaft.")
        }
    }

    private var baseInfoSection: some View {
        Section("Karte") {
            LabeledContent("Name", value: stack.cardName)
            if let setName = stack.setName, !setName.isEmpty {
                LabeledContent("Set", value: setName)
            }
            if let cardNumber = stack.cardNumber, !cardNumber.isEmpty {
                LabeledContent("Nummer", value: cardNumber)
            }
            LabeledContent("Gesamtmenge", value: "\(stack.totalQuantity)")
        }
    }

    private var conditionSection: some View {
        Section("Zustände") {
            ForEach(CardCondition.allCases.sorted(by: { $0.sortRank < $1.sortRank }), id: \.rawValue) { condition in
                Stepper(
                    conditionDisplayName(condition),
                    value: quantityBinding(for: condition),
                    in: 0...999
                )
            }
        }
    }

    private var moveCopySection: some View {
        Section("In andere Sammlung") {
            if availableDestinations.isEmpty {
                Text("Keine weitere Sammlung vorhanden.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Ziel", selection: $destinationCollectionID) {
                    ForEach(availableDestinations) { destination in
                        Text(destination.name).tag(Optional(destination.id))
                    }
                }

                Button("Stapel kopieren") {
                    copyOrMoveStack(move: false)
                }
                .disabled(destinationCollectionID == nil)

                Button("Stapel verschieben") {
                    copyOrMoveStack(move: true)
                }
                .disabled(destinationCollectionID == nil)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Stapel löschen", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }

    private var availableDestinations: [CollectionEntity] {
        collections.filter { $0.id != stack.collection?.id }
    }

    private var collections: [CollectionEntity] {
        allCollections.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func quantityBinding(for condition: CardCondition) -> Binding<Int> {
        Binding {
            stack.conditionBuckets.first(where: { $0.condition == condition })?.quantity ?? 0
        } set: { newValue in
            updateBucket(for: condition, quantity: newValue)
        }
    }

    private func updateBucket(for condition: CardCondition, quantity: Int) {
        let clampedQuantity = max(0, quantity)

        if let existingBucket = stack.conditionBuckets.first(where: { $0.condition == condition }) {
            if clampedQuantity == 0 {
                stack.conditionBuckets.removeAll(where: { $0.id == existingBucket.id })
                modelContext.delete(existingBucket)
            } else {
                existingBucket.quantity = clampedQuantity
            }
        } else if clampedQuantity > 0 {
            let bucket = ConditionBucketEntity(condition: condition, quantity: clampedQuantity, cardStack: stack)
            stack.conditionBuckets.append(bucket)
            modelContext.insert(bucket)
        }

        touchStack()
        try? modelContext.save()
    }

    private func deleteStack() {
        if let collection = stack.collection {
            collection.updatedAt = .now
        }
        modelContext.delete(stack)
        try? modelContext.save()
        dismiss()
    }

    private func copyOrMoveStack(move: Bool) {
        guard
            let destinationCollectionID,
            let destination = collections.first(where: { $0.id == destinationCollectionID })
        else {
            return
        }

        let copiedStack = CardStackEntity(
            canonicalCardID: stack.canonicalCardID,
            cardName: stack.cardName,
            setName: stack.setName,
            cardNumber: stack.cardNumber,
            imageURLString: stack.imageURLString,
            generalPrice: stack.generalPrice,
            createdAt: .now,
            updatedAt: .now,
            collection: destination
        )

        modelContext.insert(copiedStack)
        destination.cardStacks.append(copiedStack)

        for bucket in stack.conditionBuckets where bucket.quantity > 0 {
            let copiedBucket = ConditionBucketEntity(
                condition: bucket.condition,
                quantity: bucket.quantity,
                conditionPrice: bucket.conditionPrice,
                isApproximatePrice: bucket.isApproximatePrice,
                cardStack: copiedStack
            )
            copiedStack.conditionBuckets.append(copiedBucket)
            modelContext.insert(copiedBucket)
        }

        destination.updatedAt = .now
        destination.lastUsedAt = .now

        if move {
            if let source = stack.collection {
                source.updatedAt = .now
            }
            modelContext.delete(stack)
            try? modelContext.save()
            dismiss()
            return
        }

        try? modelContext.save()
    }

    private func touchStack() {
        stack.updatedAt = .now
        if let collection = stack.collection {
            collection.updatedAt = .now
        }
    }

    private func conditionDisplayName(_ condition: CardCondition) -> String {
        switch condition {
        case .mint: return "Mint"
        case .nearMint: return "Near Mint"
        case .lightlyPlayed: return "Lightly Played"
        case .moderatelyPlayed: return "Moderately Played"
        case .heavilyPlayed: return "Heavily Played"
        case .damaged: return "Damaged"
        }
    }
}
