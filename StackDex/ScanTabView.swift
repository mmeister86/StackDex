import AVFoundation
import Photos
import SwiftData
import SwiftUI
import UIKit

struct ScanTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCollections: [CollectionEntity]

    @StateObject private var camera = CameraCaptureService()
    @StateObject private var recentPhotos = RecentPhotoLibraryService()

    @State private var isProcessing = false
    @State private var scanOutcome = ScanResultPolicy.Outcome(state: .noMatch, candidates: [])
    @State private var lastHints = ScanLookupHints(normalizedQuery: "", nameTokens: [], possibleNumbers: [])
    @State private var selectedCandidateID: String?
    @State private var quantity: Int = 1
    @State private var selectedCondition: CardCondition?
    @State private var selectedTargetCollectionID: UUID?
    @State private var separateStack = false
    @State private var manualSearchQuery = ""
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    private let lookupService: any CardLookupServing = MockCardLookupService()
    private let scanPipeline: any ScanPipelineServing = VisionScanPipelineService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cameraSection
                    recentPhotosSection
                    scanResultSection
                    manualSearchSection
                }
                .padding(16)
            }
            .navigationTitle("Scannen")
            .onAppear {
                prepareDefaultsIfNeeded()
                camera.refreshAuthorizationStatus()
                recentPhotos.refreshAuthorizationStatus()
                if camera.authorizationStatus == .authorized {
                    camera.startSessionIfAuthorized()
                }
                if recentPhotos.authorizationStatus == .authorized || recentPhotos.authorizationStatus == .limited {
                    recentPhotos.loadRecent()
                }
            }
            .onDisappear {
                camera.stopSession()
            }
            .onChange(of: collections.map(\.id)) { _, _ in
                if !collections.contains(where: { $0.id == selectedTargetCollectionID }) {
                    selectedTargetCollectionID = AppStateAccess.defaultSaveTargetCollectionID(
                        in: modelContext,
                        collections: collections
                    )
                }
            }
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kamera")
                .font(.headline)

            Group {
                switch camera.authorizationStatus {
                case .authorized:
                    cameraPreview
                case .notDetermined:
                    permissionCard(
                        title: "Kamerazugriff erforderlich",
                        message: "Der Zugriff wird erst beim Start des Scans angefragt.",
                        primaryTitle: "Kamera erlauben"
                    ) {
                        Task {
                            if await camera.requestAccessIfNeeded() {
                                camera.startSessionIfAuthorized()
                            }
                        }
                    }
                case .denied, .restricted:
                    permissionCard(
                        title: "Kamera deaktiviert",
                        message: "Aktiviere den Zugriff in den Einstellungen, um direkt zu scannen.",
                        primaryTitle: "Einstellungen öffnen"
                    ) {
                        openSettings()
                    }
                @unknown default:
                    permissionCard(
                        title: "Kamera nicht verfügbar",
                        message: "Dieser Zustand wird aktuell nicht unterstützt.",
                        primaryTitle: "Einstellungen öffnen"
                    ) {
                        openSettings()
                    }
                }
            }
        }
    }

    private var cameraPreview: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: camera.session)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 14) {
                Button {
                    captureFromCamera()
                } label: {
                    Label("Aufnehmen", systemImage: "camera.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)

                if let targetCollectionName {
                    Text("Ziel: \(targetCollectionName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.bottom, 12)
        }
    }

    private var recentPhotosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Letzte Fotos")
                    .font(.headline)
                Spacer()
                if recentPhotos.authorizationStatus == .limited {
                    Button("Auswahl erweitern") {
                        recentPhotos.presentLimitedLibraryPicker()
                    }
                    .font(.caption)
                }
            }

            switch recentPhotos.authorizationStatus {
            case .authorized, .limited:
                if recentPhotos.items.isEmpty {
                    Button("Aktualisieren") {
                        recentPhotos.loadRecent()
                    }
                    .buttonStyle(.bordered)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(recentPhotos.items) { item in
                                Button {
                                    Task {
                                        await scanRecentPhoto(item)
                                    }
                                } label: {
                                    Image(uiImage: item.thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(isProcessing)
                            }
                        }
                    }
                }
            case .notDetermined:
                permissionCard(
                    title: "Fotozugriff bei Bedarf",
                    message: "Nur fuer die letzten Fotos im Scan-Screen.",
                    primaryTitle: "Fotos erlauben"
                ) {
                    Task {
                        let status = await recentPhotos.requestAccessIfNeeded()
                        if status == .authorized || status == .limited {
                            recentPhotos.loadRecent()
                        }
                    }
                }
            case .denied, .restricted:
                permissionCard(
                    title: "Fotos nicht verfuegbar",
                    message: "Aktiviere Zugriff in den Einstellungen oder waehle spaeter manuell.",
                    primaryTitle: "Einstellungen öffnen"
                ) {
                    openSettings()
                }
            @unknown default:
                EmptyView()
            }
        }
    }

    private var scanResultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ergebnis")
                .font(.headline)

            if isProcessing {
                ProgressView("Karte wird erkannt...")
            } else if scanOutcome.candidates.isEmpty {
                Text("Noch kein Treffer. Nutze Kamera, letzte Fotos oder die manuelle Suche.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if scanOutcome.state == .uncertain {
                    Text("Die Erkennung ist nicht ganz sicher. Bitte Kandidat kurz pruefen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if scanOutcome.state == .strong {
                    Text("Top-Treffer gefunden. Du kannst vor dem Speichern noch anpassen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                candidatePicker
                saveForm
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var candidatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(scanOutcome.candidates) { candidate in
                CandidateRowView(
                    title: candidate.identity.name,
                    subtitle: detailLine(for: candidate.identity),
                    isSelected: selectedCandidateID == candidate.id
                ) {
                    selectedCandidateID = candidate.id
                }
            }
        }
    }

    private var saveForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper("Menge: \(quantity)", value: $quantity, in: 1...999)

            Picker("Zustand (optional)", selection: $selectedCondition) {
                Text("Nicht angegeben").tag(Optional<CardCondition>.none)
                ForEach(CardCondition.allCases, id: \.rawValue) { condition in
                    Text(conditionDisplayName(condition)).tag(Optional(condition))
                }
            }

            Picker("Zielsammlung", selection: $selectedTargetCollectionID) {
                ForEach(collections) { collection in
                    Text(collection.name).tag(Optional(collection.id))
                }
            }

            Toggle("Als separaten Stapel speichern", isOn: $separateStack)

            Button("In Sammlung speichern") {
                saveSelection()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCandidate == nil || selectedTargetCollectionID == nil || quantity < 1)
        }
    }

    private var manualSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manuelle Suche")
                .font(.headline)

            TextField("Name, Set oder Nummer", text: $manualSearchQuery)
                .textFieldStyle(.roundedBorder)

            Button("Suche starten") {
                Task {
                    await performManualLookup()
                }
            }
            .buttonStyle(.bordered)
            .disabled(manualSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        }
    }

    private var selectedCandidate: CardLookupCandidate? {
        scanOutcome.candidates.first(where: { $0.id == selectedCandidateID })
    }

    private var collections: [CollectionEntity] {
        allCollections.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var targetCollectionName: String? {
        guard let selectedTargetCollectionID else { return nil }
        return collections.first(where: { $0.id == selectedTargetCollectionID })?.name
    }

    private func prepareDefaultsIfNeeded() {
        if selectedTargetCollectionID == nil {
            selectedTargetCollectionID = AppStateAccess.defaultSaveTargetCollectionID(
                in: modelContext,
                collections: collections
            )
        }
    }

    private func captureFromCamera() {
        camera.capturePhoto { result in
            switch result {
            case .success(let image):
                Task {
                    await recognizeAndLookup(input: .captured(image))
                }
            case .failure:
                errorMessage = "Foto konnte nicht aufgenommen werden."
            }
        }
    }

    private func scanRecentPhoto(_ item: RecentPhotoLibraryService.Item) async {
        guard let image = await recentPhotos.loadFullImage(for: item) else {
            errorMessage = "Foto konnte nicht geladen werden."
            return
        }
        await recognizeAndLookup(input: .imported(image))
    }

    @MainActor
    private func recognizeAndLookup(input: ScanImageInput) async {
        isProcessing = true
        errorMessage = nil
        infoMessage = nil

        do {
            let pipelineResult = try await scanPipeline.process(input: input, settings: .default)
            lastHints = pipelineResult.hints

            let candidates = await lookupService.lookupCandidates(
                for: CardLookupRequest(
                    recognizedTexts: pipelineResult.recognizedTexts,
                    hints: pipelineResult.hints,
                    maxResults: 3
                )
            )

            let outcome = ScanResultPolicy.evaluate(candidates: candidates, maxCandidates: 3)
            applyLookupOutcome(outcome, hints: pipelineResult.hints)
        } catch {
            errorMessage = "Erkennung fehlgeschlagen. Bitte erneut versuchen."
        }

        isProcessing = false
    }

    @MainActor
    private func performManualLookup() async {
        isProcessing = true
        errorMessage = nil
        infoMessage = nil

        let query = manualSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let hints = ScanLookupHints(
            normalizedQuery: query,
            nameTokens: query.split(separator: " ").map(String.init),
            possibleNumbers: query.split(separator: " ").map(String.init).filter { Int($0) != nil }
        )

        let candidates = await lookupService.lookupCandidates(
            for: CardLookupRequest(recognizedTexts: [query], hints: hints, maxResults: 3)
        )
        let outcome = ScanResultPolicy.evaluate(candidates: candidates, maxCandidates: 3)
        applyLookupOutcome(outcome, hints: hints)
        isProcessing = false
    }

    private func applyLookupOutcome(_ outcome: ScanResultPolicy.Outcome, hints: ScanLookupHints) {
        scanOutcome = outcome
        selectedCandidateID = outcome.candidates.first?.id

        if case .manualSearch(let prefilledQuery) = ScanFlowRoutingPolicy.nextStep(outcome: outcome, hints: hints), !prefilledQuery.isEmpty {
            manualSearchQuery = prefilledQuery
            infoMessage = "Kein sicherer Treffer. Manuelle Suche wurde mit Hinweisen vorbelegt."
        }
    }

    private func saveSelection() {
        guard
            let candidate = selectedCandidate,
            let selectedTargetCollectionID,
            let targetCollection = collections.first(where: { $0.id == selectedTargetCollectionID })
        else {
            errorMessage = "Bitte Ziel und Karte auswaehlen."
            return
        }

        let existing = collections.flatMap { collection in
            collection.cardStacks.map {
                CollectionRules.ExistingStackRecord(
                    stackID: $0.id,
                    collectionID: collection.id,
                    canonicalCardID: $0.canonicalCardID
                )
            }
        }

        let decision = ScanSavePlanner.resolveStackDecision(
            identity: candidate.identity,
            targetCollectionID: selectedTargetCollectionID,
            existingStacks: existing,
            explicitSeparateStack: separateStack
        )

        switch decision {
        case .merge(let stackID):
            guard let stack = targetCollection.cardStacks.first(where: { $0.id == stackID }) else {
                errorMessage = "Stapel konnte nicht gefunden werden."
                return
            }
            update(stack: stack, using: candidate)
            addQuantity(to: stack)
            infoMessage = "Zur vorhandenen Karte hinzugefuegt."
        case .createNewStack:
            let stack = CardStackEntity(
                canonicalCardID: candidate.identity.canonicalCardID,
                cardName: candidate.identity.name,
                setName: candidate.identity.setName,
                cardNumber: candidate.identity.cardNumber,
                imageURLString: candidate.imageURLString,
                generalPrice: candidate.generalPrice,
                createdAt: .now,
                updatedAt: .now,
                collection: targetCollection
            )

            modelContext.insert(stack)
            targetCollection.cardStacks.append(stack)
            addQuantity(to: stack)
            infoMessage = "Neue Karte in der Sammlung gespeichert."
        }

        targetCollection.updatedAt = .now
        targetCollection.lastUsedAt = .now
        AppStateAccess.setActiveCollectionID(targetCollection.id, in: modelContext)
        try? modelContext.save()
        clearTransientScanState()
    }

    private func update(stack: CardStackEntity, using candidate: CardLookupCandidate) {
        stack.updatedAt = .now
        if stack.imageURLString == nil {
            stack.imageURLString = candidate.imageURLString
        }
        if stack.generalPrice == nil {
            stack.generalPrice = candidate.generalPrice
        }
    }

    private func addQuantity(to stack: CardStackEntity) {
        let resolvedCondition = selectedCondition ?? .nearMint

        if let existingBucket = stack.conditionBuckets.first(where: { $0.condition == resolvedCondition }) {
            existingBucket.quantity += quantity
            if selectedCondition == nil {
                existingBucket.isApproximatePrice = true
            }
            return
        }

        let bucket = ConditionBucketEntity(
            condition: resolvedCondition,
            quantity: quantity,
            isApproximatePrice: selectedCondition == nil,
            cardStack: stack
        )
        stack.conditionBuckets.append(bucket)
        modelContext.insert(bucket)
    }

    private func clearTransientScanState() {
        scanOutcome = .init(state: .noMatch, candidates: [])
        selectedCandidateID = nil
        quantity = 1
        selectedCondition = nil
        separateStack = false
    }

    private func permissionCard(
        title: String,
        message: String,
        primaryTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(primaryTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(0.08))
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func detailLine(for identity: CardIdentity) -> String {
        switch (identity.setName, identity.cardNumber) {
        case let (.some(setName), .some(cardNumber)) where !setName.isEmpty && !cardNumber.isEmpty:
            return "\(setName) • #\(cardNumber)"
        case let (.some(setName), _):
            return setName
        case let (_, .some(cardNumber)):
            return "#\(cardNumber)"
        default:
            return "Set unbekannt"
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

private struct CandidateRowView: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
