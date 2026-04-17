import AVFoundation
import OSLog
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
    @State private var lastCandidateValidation = ScanCandidateValidationPolicy.Result.empty
    @State private var lastLookupAttempts: [ScanLookupAttempt] = []
    @State private var lastPipelineResult: ScanPipelineResult?
    @State private var selectedCandidateID: String?
    @State private var quantity: Int = 1
    @State private var selectedCondition: CardCondition?
    @State private var selectedTargetCollectionID: UUID?
    @State private var separateStack = false
    @State private var manualSearchQuery = ""
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var isResultSheetPresented = false
    @State private var selectedResultSheetDetent: PresentationDetent = .fraction(0.36)
    @FocusState private var isManualSearchFocused: Bool

    private let lookupService: any CardLookupServing
    private let scanLookupService: any ScanLookupServing
    private let scanPipeline: any ScanPipelineServing
    private let onOCRDebugSnapshotUpdate: (ScanOCRDebugSnapshot) -> Void
    private let logger = Logger(subsystem: "de.stackdex.app", category: "scan.ui")

    init(
        lookupService: any CardLookupServing = CardLookupServiceFactory.makeDefault(),
        scanPipeline: any ScanPipelineServing = VisionScanPipelineService(),
        onOCRDebugSnapshotUpdate: @escaping (ScanOCRDebugSnapshot) -> Void = { _ in }
    ) {
        self.lookupService = lookupService
        self.scanLookupService = ProgressiveScanLookupService(base: lookupService)
        self.scanPipeline = scanPipeline
        self.onOCRDebugSnapshotUpdate = onOCRDebugSnapshotUpdate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                scannerShellSection
                    .layoutPriority(1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Scannen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isResultSheetPresented = true
                    } label: {
                        Label("Suche", systemImage: "magnifyingglass")
                    }
                    .accessibilityIdentifier("scan.sheet.open")
                }
            }
            .sheet(isPresented: $isResultSheetPresented) {
                resultSheetContent
                    .presentationDetents([.fraction(0.36), .medium, .large], selection: $selectedResultSheetDetent)
                    .presentationDragIndicator(.visible)
            }
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

    private var scannerShellSection: some View {
        ZStack {
            scannerCanvas
            scannerShellChrome
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 420)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.shell.root")
    }

    private var scannerCanvas: some View {
        ZStack {
            Group {
                switch camera.authorizationStatus {
                case .authorized:
                    cameraPreview
                case .notDetermined:
                    permissionCard(
                        title: "Kamerazugriff erforderlich",
                        message: "Der Scanner bleibt bereit und fragt den Zugriff erst beim Aufnehmen an.",
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

            if !camera.liveOCRBoundingBoxes.isEmpty {
                ScanOCRBoundingBoxesOverlay(
                    boxes: camera.liveOCRBoundingBoxes,
                    overlayAccessibilityIdentifier: "scan.shell.liveOcrBoxes"
                )

                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("scan.shell.liveOcrBoxes.marker")
            }

            ScannerFocusOverlayView(
                focusState: camera.focusIndicatorState,
                isVisible: true
            )

            LinearGradient(
                colors: [.clear, .black.opacity(0.14), .black.opacity(0.38)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.22), Color.black.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .accessibilityIdentifier("scan.shell.canvas")
    }

    private var scannerShellChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                recentPhotoShortcutButton
            }
            .padding(.top, 2)

            if case let .interrupted(message) = camera.interruptionState {
                interruptionBanner(message: message)
                    .padding(.top, 10)
            }

            Spacer(minLength: 16)

            scannerFrameOverlay

            Spacer(minLength: 14)

            zoomControls

            Button(action: handleCaptureButtonTap) {
                Label("Aufnehmen", systemImage: "camera.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .frame(minWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .foregroundStyle(.white)
            .disabled(isProcessing || hasActiveScannerInterruption)
            .accessibilityIdentifier("scan.shell.capture")
        }
        .padding(18)
    }

    private func interruptionBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "camera.metering.unknown")
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("scan.shell.interruption")
    }

    private var recentPhotoShortcutButton: some View {
        Button(action: handleRecentPhotoShortcutTap) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let latestItem = recentPhotos.latestItem {
                        Image(uiImage: latestItem.thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.black.opacity(0.28))
                            .overlay {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Image(systemName: "photo")
                    .font(.system(size: 9, weight: .bold))
                    .padding(5)
                    .background(.ultraThinMaterial, in: Circle())
                    .offset(x: 3, y: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Letztes Foto verwenden")
        .accessibilityHint("Oeffnet das neueste Foto oder fragt Fotozugriff an")
        .accessibilityIdentifier("scan.shell.recentPhotoShortcut")
    }

    private var scannerFrameOverlay: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width * 0.7, 270)
            let height = width * 1.4
            let overlayBoxes = ocrBoundingBoxes

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.black.opacity(0.18))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.92), style: StrokeStyle(lineWidth: 3, dash: [16, 10]))

                    if !overlayBoxes.isEmpty {
                        ScanOCRBoundingBoxesOverlay(boxes: overlayBoxes)
                    }
                }
                .frame(width: width, height: height)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Scanner-Rahmen")
                .accessibilityIdentifier("scan.shell.frame")

                Text("Karte innerhalb des Rahmens halten, Blendung vermeiden.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("scan.shell.guidance")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityElement(children: .contain)
        }
    }

    private var ocrBoundingBoxes: [CGRect] {
        guard let pipelineResult = lastPipelineResult else {
            return []
        }

        return pipelineResult.rawObservations
            .map(\.boundingBox)
            .map { $0.clampedToUnitRect() }
            .filter { !$0.isEmpty }
    }

    private var cameraPreview: some View {
        CameraPreviewView(camera: camera)
    }

    private var resultSheetContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ergebnis")
                        .font(.headline)

                    Text(accessorySummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("scan.info.message")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("scan.error.message")
            }

            scanResultSection

            VStack(alignment: .leading, spacing: 10) {
                Divider()

                Text("Manuelle Suche")
                    .font(.subheadline.weight(.semibold))

                manualSearchSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scan.sheet.root")
    }

    private var hasActiveScannerInterruption: Bool {
        if case .interrupted = camera.interruptionState {
            return true
        }

        return false
    }

    private var canUseZoomControls: Bool {
        camera.authorizationStatus == .authorized
        && camera.isSessionRunning
        && !hasActiveScannerInterruption
    }

    @ViewBuilder
    private var zoomControls: some View {
        if camera.zoomState.isAvailable {
            HStack(spacing: 10) {
                ForEach(camera.zoomState.steps, id: \.self) { factor in
                    let isSelected = abs(camera.zoomState.current - factor) < 0.07

                    Button {
                        camera.setZoomFactor(factor, animated: true)
                    } label: {
                        Text(zoomLabel(for: factor))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isSelected ? Color.black : Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.22))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canUseZoomControls)
                    .accessibilityIdentifier("scan.shell.zoom.\(zoomIdentifier(for: factor))")
                    .accessibilityValue(isSelected ? "Ausgewaehlt" : "Nicht ausgewaehlt")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.black.opacity(0.28))
            )
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("scan.shell.zoom.controls")
        }
    }

    private func zoomLabel(for factor: CGFloat) -> String {
        let rounded = (factor * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.05 {
            return "\(Int(rounded))x"
        }

        return "\(String(format: "%.1f", rounded))x"
    }

    private func zoomIdentifier(for factor: CGFloat) -> String {
        let label = zoomLabel(for: factor)
        return label.replacingOccurrences(of: ".", with: "_")
    }

    private var accessorySummary: String {
        if isProcessing {
            return "Die letzte Aufnahme wird gerade verarbeitet."
        }

        if !scanOutcome.candidates.isEmpty {
            switch scanOutcome.state {
            case .strong:
                return "Top-Treffer gefunden. Vor dem Speichern kannst du ihn noch pruefen."
            case .uncertain:
                return "Bitte Kandidat kurz pruefen, die Erkennung ist nicht ganz sicher."
            case .noMatch:
                break
            }
        }

        return "Noch kein Treffer. Kamera oder letztes Foto starten den Lookup, Suche bleibt als Fallback erreichbar."
    }

    private var scanResultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if scanOutcome.candidates.isEmpty {
                Text("Noch kein Treffer. Nutze die Kamera oder das letzte Foto, um Kandidaten hier einzuchecken.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("scan.results.empty")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        candidatePicker
                        saveForm
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 260)
            }

            #if DEBUG
            if let lastPipelineResult {
                debugPanel(for: lastPipelineResult, attempts: lastLookupAttempts, validation: lastCandidateValidation)
            }
            #endif
        }
    }

    private var candidatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(scanOutcome.candidates) { candidate in
                CandidateRowView(
                    title: candidate.identity.name,
                    subtitle: detailLine(for: candidate.identity),
                    valueHint: valueHint(for: candidate),
                    imageURLString: candidate.imageURLString,
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
            .accessibilityIdentifier("scan.save.targetCollection")

            Toggle("Als separaten Stapel speichern", isOn: $separateStack)

            Button("In Sammlung speichern") {
                saveSelection()
            }
            .accessibilityIdentifier("scan.save.submit")
            .buttonStyle(.borderedProminent)
            .disabled(selectedCandidate == nil || selectedTargetCollectionID == nil || quantity < 1)
        }
    }

    private var manualSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name, Set oder Nummer", text: $manualSearchQuery)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .focused($isManualSearchFocused)
                .onSubmit {
                    Task {
                        await performManualLookup()
                    }
                }
                .accessibilityIdentifier("scan.manual.query")

            Button("Suche starten") {
                Task {
                    await performManualLookup()
                }
            }
            .accessibilityIdentifier("scan.manual.submit")
            .buttonStyle(.bordered)
            .disabled(manualSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)

            if recentPhotos.authorizationStatus == .limited {
                Button("Fotoauswahl erweitern") {
                    recentPhotos.presentLimitedLibraryPicker()
                }
                .font(.footnote)
                .buttonStyle(.bordered)
            }
        }
    }

    private func handleCaptureButtonTap() {
        switch camera.authorizationStatus {
        case .authorized:
            captureFromCamera()
        case .notDetermined:
            Task {
                if await camera.requestAccessIfNeeded() {
                    camera.startSessionIfAuthorized()
                }
            }
        case .denied, .restricted:
            openSettings()
        @unknown default:
            openSettings()
        }
    }

    private func handleRecentPhotoShortcutTap() {
        switch recentPhotos.authorizationStatus {
        case .authorized, .limited:
            if let latestItem = recentPhotos.latestItem {
                Task {
                    await scanRecentPhoto(latestItem)
                }
            } else {
                recentPhotos.loadRecent()
            }
        case .notDetermined:
            Task {
                let status = await recentPhotos.requestAccessIfNeeded()
                if status == .authorized || status == .limited {
                    recentPhotos.loadRecent()
                }
            }
        case .denied, .restricted:
            openSettings()
        @unknown default:
            recentPhotos.loadRecent()
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
                logger.error("Capture failed before OCR")
                errorMessage = "Foto konnte nicht aufgenommen werden."
                isResultSheetPresented = true
            }
        }
    }

    private func scanRecentPhoto(_ item: RecentPhotoLibraryService.Item) async {
        guard let image = await recentPhotos.loadFullImage(for: item) else {
            logger.error("Import failed before OCR")
            errorMessage = "Foto konnte nicht geladen werden."
            isResultSheetPresented = true
            return
        }
        await recognizeAndLookup(input: .imported(image))
    }

    @MainActor
    private func recognizeAndLookup(input: ScanImageInput) async {
        isProcessing = true
        errorMessage = nil
        infoMessage = nil
        lastLookupAttempts = []
        lastPipelineResult = nil

        do {
            let qualityPreset = AppStateAccess.scanOCRQualityPreset(in: modelContext)
            let postProcessMode = AppStateAccess.scanOCRPostProcessMode(in: modelContext)
            var pipelineSettings = qualityPreset.settings
            pipelineSettings.postProcessMode = postProcessMode

            let pipelineResult = try await scanPipeline.process(
                input: input,
                settings: pipelineSettings
            )
            lastPipelineResult = pipelineResult
            onOCRDebugSnapshotUpdate(
                ScanOCRDebugSnapshot(
                    updatedAt: .now,
                    source: pipelineResult.source,
                    rawObservations: pipelineResult.rawObservations
                )
            )
            lastHints = pipelineResult.hints
            lastCandidateValidation = .empty

            if pipelineResult.usedFullImageFallback {
                appendInfoMessage("Kartenrahmen nicht sicher erkannt. Vollbild-Fallback wurde verwendet.")
            }

            if pipelineResult.usedFullImageFallback && !pipelineResult.hints.hasStrongLookupSignal {
                logger.info("Scan aborted due to weak fallback-only OCR signals")
                scanOutcome = .init(state: .noMatch, candidates: [])
                selectedCandidateID = nil
                appendInfoMessage("Scan verworfen: kein verlässlicher Name oder keine Sammlernummer erkannt.")
                errorMessage = "Kein verlässlicher Treffer. Bitte Karte vollständig und frontal im Rahmen platzieren."
                isResultSheetPresented = true
                isProcessing = false
                return
            }

            guard !pipelineResult.recognizedFields.isEmpty,
                  !pipelineResult.hints.normalizedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                logger.info("OCR produced no high-confidence fields")
                scanOutcome = .init(state: .noMatch, candidates: [])
                selectedCandidateID = nil
                appendInfoMessage("Unsichere OCR-Treffer wurden konservativ verworfen.")
                errorMessage = "Es konnten keine verlässlichen Kartenfelder erkannt werden."
                isResultSheetPresented = true
                isProcessing = false
                return
            }

            let lookupResponse = await scanLookupService.lookupScanCandidates(
                for: CardLookupRequest(
                    recognizedTexts: pipelineResult.recognizedTexts,
                    query: pipelineResult.hints.normalizedQuery,
                    hints: pipelineResult.hints,
                    maxResults: 3
                )
            )
            lastLookupAttempts = lookupResponse.attempts
            let validation = ScanCandidateValidationPolicy.validate(
                candidates: lookupResponse.candidates,
                hints: pipelineResult.hints
            )
            lastCandidateValidation = validation

            let outcome = ScanResultPolicy.evaluate(candidates: validation.candidates, maxCandidates: 3)
            applyLookupOutcome(
                outcome,
                hints: pipelineResult.hints,
                lookupResponse: lookupResponse,
                validation: validation
            )
        } catch {
            logger.error("Scan recognition failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Erkennung fehlgeschlagen. Bitte erneut versuchen."
            isResultSheetPresented = true
        }

        isProcessing = false
    }

    @MainActor
    private func performManualLookup() async {
        isProcessing = true
        isManualSearchFocused = false
        errorMessage = nil
        infoMessage = nil
        lastLookupAttempts = []
        lastPipelineResult = nil

        let query = manualSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let hints = ScanLookupHints(
            normalizedQuery: query,
            nameTokens: query.split(separator: " ").map(String.init),
            possibleNumbers: query.split(separator: " ").map(String.init).filter { Int($0) != nil }
        )

        let candidates = await lookupService.lookupCandidates(
            for: CardLookupRequest(recognizedTexts: [query], query: query, hints: hints, maxResults: 3)
        )
        let validation = ScanCandidateValidationPolicy.validate(candidates: candidates, hints: hints)
        lastCandidateValidation = validation
        lastLookupAttempts = [
            ScanLookupAttempt(
                strategy: .structuredNameOnly,
                query: query,
                candidateCount: candidates.count
            ),
        ]
        let outcome = ScanResultPolicy.evaluate(candidates: validation.candidates, maxCandidates: 3)
        applyLookupOutcome(
            outcome,
            hints: hints,
            lookupResponse: nil,
            validation: validation
        )
        isProcessing = false
    }

    private func applyLookupOutcome(
        _ outcome: ScanResultPolicy.Outcome,
        hints: ScanLookupHints,
        lookupResponse: ScanLookupResponse?,
        validation: ScanCandidateValidationPolicy.Result
    ) {
        scanOutcome = outcome
        selectedCandidateID = outcome.candidates.first?.id
        isResultSheetPresented = true

        if let lookupResponse, lookupResponse.attempts.count > 1 {
            appendInfoMessage("Suche mit \(lookupResponse.attempts.count) Varianten verfeinert.")
            selectedResultSheetDetent = .medium
        }

        if case .manualSearch(let prefilledQuery) = ScanFlowRoutingPolicy.nextStep(outcome: outcome, hints: hints) {
            let query = validation.numberGuardApplied ? (validation.comparedNumber ?? prefilledQuery) : prefilledQuery
            if !query.isEmpty {
                manualSearchQuery = query
                appendInfoMessage("Manuelle Suche wurde mit Hinweisen vorbelegt.")
            }
        }

        if outcome.state == .noMatch {
            logger.info("Lookup returned no candidates")
            errorMessage = "Kein passender Kartenkandidat gefunden."
            selectedResultSheetDetent = .medium
        }
    }

    private func appendInfoMessage(_ message: String) {
        guard !message.isEmpty else {
            return
        }

        guard let current = infoMessage, !current.isEmpty else {
            infoMessage = message
            return
        }

        if !current.contains(message) {
            infoMessage = "\(current) \(message)"
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
            addQuantity(to: stack, using: candidate)
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
            addQuantity(to: stack, using: candidate)
            infoMessage = "Neue Karte in der Sammlung gespeichert."
        }

        targetCollection.updatedAt = .now
        targetCollection.lastUsedAt = .now
        AppStateAccess.setActiveCollectionID(targetCollection.id, in: modelContext)
        try? modelContext.save()
        isResultSheetPresented = false
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

    private func addQuantity(to stack: CardStackEntity, using candidate: CardLookupCandidate) {
        let resolvedCondition = selectedCondition ?? .nearMint
        let pricing = ScanPricingPolicy.resolve(candidate: candidate, selectedCondition: selectedCondition)

        if let existingBucket = stack.conditionBuckets.first(where: { $0.condition == resolvedCondition }) {
            existingBucket.quantity += quantity

            let existingResolution = ScanPricingPolicy.Resolution(
                conditionPrice: existingBucket.conditionPrice,
                isApproximatePrice: existingBucket.isApproximatePrice
            )
            let mergedResolution = ScanPricingPolicy.merge(existing: existingResolution, incoming: pricing)
            existingBucket.conditionPrice = mergedResolution.conditionPrice
            existingBucket.isApproximatePrice = mergedResolution.isApproximatePrice
            return
        }

        let bucket = ConditionBucketEntity(
            condition: resolvedCondition,
            quantity: quantity,
            conditionPrice: pricing.conditionPrice,
            isApproximatePrice: pricing.isApproximatePrice,
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

    private func valueHint(for candidate: CardLookupCandidate) -> String? {
        if let generalPrice = candidate.generalPrice {
            return "Marktwert: \(currencyString(from: generalPrice))"
        }

        if let fallback = candidate.conditionPrices.values.max() {
            return "Ca. \(currencyString(from: fallback))"
        }

        return nil
    }

    private func currencyString(from decimal: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: decimal as NSDecimalNumber) ?? "-"
    }

    #if DEBUG
    @ViewBuilder
    private func debugPanel(for result: ScanPipelineResult, attempts: [ScanLookupAttempt], validation: ScanCandidateValidationPolicy.Result) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug")
                .font(.caption.weight(.semibold))
            Text("Query: \(result.hints.normalizedQuery.isEmpty ? "-" : result.hints.normalizedQuery)")
                .font(.caption2)
            Text("SignalQuality: weakName=\(result.hints.signalQuality.isWeakNameSignal ? "true" : "false"), collectorNumber=\(result.hints.signalQuality.hasCollectorNumberSignal ? "true" : "false"), suspiciousSetCode=\(result.hints.signalQuality.hasSuspiciousSetCodes ? "true" : "false")")
                .font(.caption2)
            Text("NumberGuard: applied=\(validation.numberGuardApplied ? "true" : "false"), filteredCount=\(validation.numberGuardFilteredCount)")
                .font(.caption2)
            Text("Compared number: \(validation.comparedNumber ?? "-")")
                .font(.caption2)
            Text("Set-Codes: \(result.hints.possibleSetCodes.isEmpty ? "-" : result.hints.possibleSetCodes.joined(separator: ", "))")
                .font(.caption2)
            Text("Rarity: \(result.hints.possibleRarities.isEmpty ? "-" : result.hints.possibleRarities.joined(separator: ", "))")
                .font(.caption2)
            Text("Language: \(result.hints.possibleLanguages.isEmpty ? "-" : result.hints.possibleLanguages.joined(separator: ", "))")
                .font(.caption2)
            Text("Strategy: \(attempts.last?.strategy.rawValue ?? "-")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(Array(result.recognizedFields.prefix(3).enumerated()), id: \.offset) { _, field in
                Text("\(field.region.rawValue): \(field.text) (\(Int(field.confidence * 100))%)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.secondary.opacity(0.08))
        )
        .accessibilityIdentifier("scan.debug.panel")
    }
    #endif
}

private struct CandidateRowView: View {
    let title: String
    let subtitle: String
    let valueHint: String?
    let imageURLString: String?
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                CandidateThumbnailView(imageURLString: imageURLString)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let valueHint {
                        Text(valueHint)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        .accessibilityIdentifier("scan.candidate.\(title)")
    }
}

private struct CandidateThumbnailView: View {
    let imageURLString: String?

    var body: some View {
        Group {
            if let imageURLString, let url = URL(string: imageURLString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: 40, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.secondary.opacity(0.12))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}

private struct ScanOCRBoundingBoxesOverlay: View {
    let boxes: [CGRect]
    var overlayAccessibilityIdentifier: String = "scan.shell.ocrBoxes"

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(boxes.enumerated()), id: \.offset) { index, box in
                let mappedBox = box.denormalized(in: proxy.size)

                if mappedBox.width > 1, mappedBox.height > 1 {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.green.opacity(0.95), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.green.opacity(0.14))
                        )
                        .frame(width: mappedBox.width, height: mappedBox.height)
                        .position(x: mappedBox.midX, y: mappedBox.midY)
                        .accessibilityIdentifier("scan.shell.ocrBox.\(index)")
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(overlayAccessibilityIdentifier)
    }
}

private extension CGRect {
    func clampedToUnitRect() -> CGRect {
        let clampedMinX = min(max(minX, 0), 1)
        let clampedMinY = min(max(minY, 0), 1)
        let clampedMaxX = min(max(maxX, 0), 1)
        let clampedMaxY = min(max(maxY, 0), 1)

        return CGRect(
            x: clampedMinX,
            y: clampedMinY,
            width: max(0, clampedMaxX - clampedMinX),
            height: max(0, clampedMaxY - clampedMinY)
        )
    }

    func denormalized(in size: CGSize) -> CGRect {
        CGRect(
            x: minX * size.width,
            y: minY * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraCaptureService

    func makeCoordinator() -> Coordinator {
        Coordinator(camera: camera)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = camera.session
        view.tapHandler = { point in
            Task { @MainActor in
                camera.focusAndExpose(atPreviewPoint: point)
            }
        }
        view.pinchHandler = { state, scale in
            Task { @MainActor in
                switch state {
                case .began:
                    camera.beginPinchZoom()
                    camera.updatePinchZoom(scale: scale)
                case .changed:
                    camera.updatePinchZoom(scale: scale)
                case .ended, .cancelled, .failed:
                    camera.endPinchZoom()
                default:
                    break
                }
            }
        }
        camera.attachPreviewLayer(view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = camera.session
        uiView.tapHandler = { point in
            Task { @MainActor in
                camera.focusAndExpose(atPreviewPoint: point)
            }
        }
        uiView.pinchHandler = { state, scale in
            Task { @MainActor in
                switch state {
                case .began:
                    camera.beginPinchZoom()
                    camera.updatePinchZoom(scale: scale)
                case .changed:
                    camera.updatePinchZoom(scale: scale)
                case .ended, .cancelled, .failed:
                    camera.endPinchZoom()
                default:
                    break
                }
            }
        }
        camera.attachPreviewLayer(uiView.previewLayer)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        uiView.prepareForTeardown()
        Task { @MainActor in
            coordinator.camera?.detachPreviewLayer()
        }
    }

    final class Coordinator {
        weak var camera: CameraCaptureService?

        init(camera: CameraCaptureService) {
            self.camera = camera
        }
    }

    final class PreviewView: UIView {
        var tapHandler: ((CGPoint) -> Void)?
        var pinchHandler: ((UIGestureRecognizer.State, CGFloat) -> Void)?

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            addGestureRecognizer(tapRecognizer)
            addGestureRecognizer(pinchRecognizer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        func prepareForTeardown() {
            tapHandler = nil
            pinchHandler = nil
            previewLayer.session = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            tapHandler?(recognizer.location(in: self))
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            pinchHandler?(recognizer.state, recognizer.scale)
        }
    }
}

private struct ScannerFocusOverlayView: View {
    let focusState: CameraCaptureService.FocusIndicatorState
    let isVisible: Bool

    var body: some View {
        GeometryReader { proxy in
            if isVisible && focusState.phase == .active {
                ScannerFocusIndicatorView(state: indicatorState)
                    .frame(width: 58, height: 58)
                    .position(indicatorPosition(in: proxy.size))
                    .accessibilityIdentifier("scan.shell.focusIndicator")
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
    }

    private var indicatorState: ScannerFocusIndicatorView.State {
        switch focusState.phase {
        case .idle:
            return .idle
        case .active:
            return .active
        }
    }

    private func indicatorPosition(in size: CGSize) -> CGPoint {
        if let previewPoint = focusState.previewPoint {
            return CGPoint(
                x: min(max(previewPoint.x, 29), max(size.width - 29, 29)),
                y: min(max(previewPoint.y, 29), max(size.height - 29, 29))
            )
        }

        return CGPoint(x: size.width / 2, y: size.height / 2)
    }
}
