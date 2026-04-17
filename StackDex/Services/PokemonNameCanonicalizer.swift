import Foundation

enum PokemonNameCanonicalizer {
    private static let store = PokemonCanonicalNameStore.load()

    static func canonicalize(_ rawName: String, suffixTokens: Set<String>) -> String? {
        store?.canonicalize(rawName, suffixTokens: suffixTokens)
    }
}

private struct PokemonCanonicalNameStore {
    private let canonicalByNormalizedName: [String: String]

    func canonicalize(_ rawName: String, suffixTokens: Set<String>) -> String? {
        let tokens = Self.lookupTokens(from: rawName)
        guard !tokens.isEmpty else {
            return nil
        }

        var baseTokens = tokens
        var trailingSuffixTokens: [String] = []

        while let lastToken = baseTokens.last, suffixTokens.contains(lastToken.lowercased()) {
            trailingSuffixTokens.insert(lastToken, at: 0)
            baseTokens.removeLast()
        }

        guard !baseTokens.isEmpty else {
            return nil
        }

        for prefixLength in stride(from: baseTokens.count, through: 1, by: -1) {
            let prefix = Array(baseTokens.prefix(prefixLength))
            let normalizedPrefix = Self.normalizeLookupKey(prefix.joined(separator: " "))
            guard let canonicalBaseName = canonicalByNormalizedName[normalizedPrefix] else {
                continue
            }

            guard prefixLength == baseTokens.count else {
                return nil
            }

            if trailingSuffixTokens.isEmpty {
                return canonicalBaseName
            }

            return ([canonicalBaseName] + trailingSuffixTokens).joined(separator: " ")
        }

        return nil
    }

    static func load() -> PokemonCanonicalNameStore? {
        guard let url = pokemonNamesResourceURL() else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let names = try JSONDecoder().decode([String].self, from: data)
            let canonicalByNormalizedName = Dictionary(
                uniqueKeysWithValues: names.map { (normalizeLookupKey($0), $0) }
            )
            return PokemonCanonicalNameStore(canonicalByNormalizedName: canonicalByNormalizedName)
        } catch {
            return nil
        }
    }

    private static func pokemonNamesResourceURL() -> URL? {
        let bundles = [Bundle.main, Bundle(for: BundleMarker.self)] + Bundle.allBundles + Bundle.allFrameworks

        for bundle in bundles {
            if let url = bundle.url(forResource: "PokemonNames", withExtension: "json") {
                return url
            }
        }

        return nil
    }

    private static func lookupTokens(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-♀♂")).inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalizeLookupKey(_ text: String) -> String {
        lookupTokens(from: text)
            .map {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                    .lowercased()
            }
            .joined(separator: " ")
    }
}

private final class BundleMarker {}
