import SwiftUI
import UIKit

struct ShareExport {
    static func textForShare(
        tradeTitle: String,
        items: [LineItem],
        notes: [String],
        currencyCode: String,
        unitPrices: [UUID: Double]
    ) -> String {
        var lines: [String] = []
        lines.append("Trade Materials Calculator — \(tradeTitle)")
        lines.append("")
        for item in items {
            let unitP = unitPrices[item.id] ?? PricingHints.defaultUnitPrice(for: item.name)
            let sub = item.quantity * unitP
            let qty = EstimateLocale.formatNumber(item.quantity)
            if unitP > 0 {
                lines.append("• \(item.name): \(qty) \(item.unit) — \(EstimateLocale.formatCurrency(sub, code: currencyCode))")
            } else {
                lines.append("• \(item.name): \(qty) \(item.unit)")
            }
        }
        let total = items.reduce(0.0) { partial, item in
            let p = unitPrices[item.id] ?? PricingHints.defaultUnitPrice(for: item.name)
            return partial + item.quantity * p
        }
        if total > 0 {
            lines.append("")
            lines.append("Total estimado: \(EstimateLocale.formatCurrency(total, code: currencyCode))")
        }
        if !notes.isEmpty {
            lines.append("")
            lines.append("Notas:")
            notes.forEach { lines.append("- \($0)") }
        }
        lines.append("")
        lines.append("Solo estimación. Verificar en sitio.")
        return lines.joined(separator: "\n")
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareEstimateSection: View {
    let tradeTitle: String
    let items: [LineItem]
    let notes: [String]
    let currencyCode: String
    let unitPrices: [UUID: Double]

    @State private var showShare = false

    var body: some View {
        Section {
            Button {
                showShare = true
            } label: {
                Label("Compartir lista", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showShare) {
            ActivityView(items: [
                ShareExport.textForShare(
                    tradeTitle: tradeTitle,
                    items: items,
                    notes: notes,
                    currencyCode: currencyCode,
                    unitPrices: unitPrices
                )
            ])
        }
    }
}
