import SwiftUI

struct ScanOCRDebugTabView: View {
    static let emptyStateMessage = "Fuehre einen Kamera- oder Foto-Scan aus, um Rohtexte zu sehen."

    let snapshot: ScanOCRDebugSnapshot?

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot, !snapshot.rawObservations.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            metadataSection(snapshot)
                            fullTextSection(snapshot)
                            candidateSection(snapshot)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                    }
                    .accessibilityIdentifier("ocr.debug.content")
                } else {
                    ContentUnavailableView {
                        Label("Noch kein OCR-Lauf", systemImage: "text.viewfinder")
                    } description: {
                        Text(Self.emptyStateMessage)
                    }
                    .accessibilityIdentifier("ocr.debug.empty")
                }
            }
            .navigationTitle("OCR Debug")
        }
    }

    private func metadataSection(_ snapshot: ScanOCRDebugSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quelle: \(sourceLabel(for: snapshot.source))")
                .font(.subheadline.weight(.semibold))
            Text("Letztes Update: \(snapshot.updatedAt.formatted(date: .abbreviated, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Observationen: \(snapshot.rawObservations.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("ocr.debug.meta")
    }

    private func fullTextSection(_ snapshot: ScanOCRDebugSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kompletter erkannter Text")
                .font(.headline)

            Text(snapshot.fullRecognizedText.isEmpty ? "-" : snapshot.fullRecognizedText)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                )
                .accessibilityIdentifier("ocr.debug.fullText")
        }
    }

    private func candidateSection(_ snapshot: ScanOCRDebugSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alle Kandidaten + Confidence")
                .font(.headline)

            ForEach(Array(snapshot.rawObservations.enumerated()), id: \.offset) { index, observation in
                let orderedCandidates = observation.candidates.sorted { $0.confidence > $1.confidence }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Observation \(index + 1) • \(observation.region.rawValue)")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(orderedCandidates.enumerated()), id: \.offset) { candidateIndex, candidate in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("#\(candidateIndex + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)

                            Text(candidate.text)
                                .font(.footnote.monospaced())

                            Spacer(minLength: 0)

                            Text(ScanOCRDebugFormatting.confidenceString(candidate.confidence))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .accessibilityIdentifier("ocr.debug.observation.\(index)")
            }
        }
        .accessibilityIdentifier("ocr.debug.candidates")
    }

    private func sourceLabel(for source: ScanImageSource) -> String {
        switch source {
        case .captured:
            return "Kamera"
        case .imported:
            return "Fotoimport"
        }
    }
}

#Preview {
    ScanOCRDebugTabView(
        snapshot: ScanOCRDebugSnapshot(
            updatedAt: .now,
            source: .captured,
            rawObservations: [
                .init(
                    region: .titleStrip,
                    boundingBox: .init(x: 0, y: 0, width: 1, height: 1),
                    candidates: [
                        .init(text: "Pikachu ex", confidence: 0.97),
                        .init(text: "Pikachu cx", confidence: 0.64),
                    ]
                ),
                .init(
                    region: .collectorFooter,
                    boundingBox: .init(x: 0, y: 0, width: 1, height: 1),
                    candidates: [
                        .init(text: "199/091", confidence: 0.95),
                    ]
                ),
            ]
        )
    )
}
