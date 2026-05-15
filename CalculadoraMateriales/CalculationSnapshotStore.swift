import Foundation
import Combine

final class CalculationSnapshotStore: ObservableObject {
    @Published private(set) var lastTradeTitle: String = ""
    @Published private(set) var lastSummaryText: String = ""
    @Published private(set) var lastUpdated: Date?

    func record(
        tradeTitle: String,
        items: [LineItem],
        notes: [String],
        currencyCode: String,
        unitPrices: [UUID: Double]
    ) {
        lastTradeTitle = tradeTitle
        lastSummaryText = Self.buildSummary(
            tradeTitle: tradeTitle,
            items: items,
            notes: notes,
            currencyCode: currencyCode,
            unitPrices: unitPrices
        )
        lastUpdated = Date()
    }

    var hasSnapshot: Bool {
        !lastSummaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func buildSummary(
        tradeTitle: String,
        items: [LineItem],
        notes: [String],
        currencyCode: String,
        unitPrices: [UUID: Double]
    ) -> String {
        var lines: [String] = []
        lines.append("=== Resultado en app (estimación) ===")
        lines.append("Oficio: \(tradeTitle)")
        lines.append("Moneda: \(currencyCode)")
        lines.append("Partidas:")
        for item in items {
            let unitP = unitPrices[item.id] ?? PricingHints.defaultUnitPrice(for: item.name)
            let sub = item.quantity * unitP
            let qty = EstimateLocale.formatNumber(item.quantity)
            let pu = EstimateLocale.formatNumber(unitP)
            if unitP > 0 {
                lines.append("- \(item.name): \(qty) \(item.unit) × \(pu) = \(EstimateLocale.formatCurrency(sub, code: currencyCode))")
            } else {
                lines.append("- \(item.name): \(qty) \(item.unit)")
            }
        }
        if !notes.isEmpty {
            lines.append("Notas del calculador:")
            notes.forEach { lines.append("• \($0)") }
        }
        var text = lines.joined(separator: "\n")
        if text.count > 6000 {
            text = String(text.prefix(6000)) + "\n… (texto recortado)"
        }
        return text
    }
}
