import Foundation

struct ValuationPresentation: Equatable {
    let formattedValue: String
    let hintKey: String?

    static func make(
        summary: ValuationCalculator.Summary,
        locale: Locale = .autoupdatingCurrent,
        currencyCode: String = Locale.autoupdatingCurrent.currency?.identifier ?? "EUR"
    ) -> ValuationPresentation {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode

        let valueText = formatter.string(from: summary.totalValue as NSDecimalNumber) ?? "0"
        let hintKey: String?

        if summary.isIncomplete {
            hintKey = "valuation.hint.incomplete"
        } else if summary.includesApproximatePricing {
            hintKey = "valuation.hint.approximate"
        } else {
            hintKey = nil
        }

        return ValuationPresentation(formattedValue: valueText, hintKey: hintKey)
    }
}
