import Foundation

/// Partida de material con cantidad y precio unitario (editable por el usuario).
struct LineItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unit: String
    /// Precio por unidad; 0 = solo cantidad, sin importe.
    var unitPrice: Double

    var subtotal: Double { quantity * unitPrice }
}

enum EstimateLocale {
    static let spanishLatinAmerica = Locale(identifier: "es-419")

    static func formatNumber(_ value: Double, fractionDigits: Int = 2) -> String {
        let f = NumberFormatter()
        f.locale = spanishLatinAmerica
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
    }

    static func formatCurrency(_ value: Double, code: String) -> String {
        let f = NumberFormatter()
        f.locale = spanishLatinAmerica
        f.numberStyle = .currency
        f.currencyCode = code
        return f.string(from: NSNumber(value: value)) ?? "\(code) \(formatNumber(value))"
    }
}

/// Precios por defecto (referencia). El usuario puede ajustarlos en pantalla.
enum PricingHints {
    static func defaultUnitPrice(for name: String) -> Double {
        let n = name.lowercased()
        if n.contains("área revestida") || n.contains("referencia compra") { return DefaultUnitPricing.tilePerM2 }
        if n.contains("cajas de registro") { return DefaultUnitPricing.boxEach }
        if n.contains("piezas de cerámica") { return 0 }
        if n.contains("cajas (aprox") { return 0 }
        if n.contains("pegamento") || n.contains("adhesivo") { return DefaultUnitPricing.tileAdhesivePerKg }
        if n.contains("lechada") || n.contains("junta") { return DefaultUnitPricing.tileGroutPerKg }
        if n.contains("pintura (total") { return DefaultUnitPricing.paintPerLiter }
        if n.contains("superficie pintada") { return 0 }
        if n.contains("volumen húmedo") { return 0 }
        if n.contains("sacos de cemento") { return DefaultUnitPricing.cementBag50kg }
        if n.contains("cemento (masa") { return DefaultUnitPricing.cementBag50kg / 50 }
        if n.contains("arena") { return DefaultUnitPricing.sandM3 }
        if n.contains("suministro") { return DefaultUnitPricing.pipeSupplyPerM }
        if n.contains("desagüe") { return DefaultUnitPricing.pipeDrainPerM }
        if n.contains("accesorios") { return DefaultUnitPricing.fittingEach }
        if n.contains("cable (aprox") { return DefaultUnitPricing.cablePerM }
        if n.contains("canalización") { return DefaultUnitPricing.conduitPerM }
        if n.contains("cajas de registro") { return DefaultUnitPricing.boxEach }
        return 0
    }
}

enum DefaultUnitPricing {
    static let currencyCode = "MXN"

    static let tilePerM2: Double = 180
    static let tileAdhesivePerKg: Double = 12
    static let tileGroutPerKg: Double = 35

    static let paintPerLiter: Double = 220

    static let cementBag50kg: Double = 280
    static let sandM3: Double = 450

    static let pipeSupplyPerM: Double = 45
    static let pipeDrainPerM: Double = 38
    static let fittingEach: Double = 15

    static let cablePerM: Double = 18
    static let conduitPerM: Double = 12
    static let boxEach: Double = 35
}
