import Foundation

enum CardCondition: String, CaseIterable, Codable, Sendable {
    case mint = "mint"
    case nearMint = "near_mint"
    case lightlyPlayed = "lightly_played"
    case moderatelyPlayed = "moderately_played"
    case heavilyPlayed = "heavily_played"
    case damaged = "damaged"

    var sortRank: Int {
        switch self {
        case .mint: 0
        case .nearMint: 1
        case .lightlyPlayed: 2
        case .moderatelyPlayed: 3
        case .heavilyPlayed: 4
        case .damaged: 5
        }
    }

    var localizationKey: String {
        switch self {
        case .mint: "condition.mint"
        case .nearMint: "condition.nearMint"
        case .lightlyPlayed: "condition.lightlyPlayed"
        case .moderatelyPlayed: "condition.moderatelyPlayed"
        case .heavilyPlayed: "condition.heavilyPlayed"
        case .damaged: "condition.damaged"
        }
    }
}
