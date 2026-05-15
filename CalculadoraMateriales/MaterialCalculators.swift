import Foundation

// Referencias de fórmulas (orientativas, campo):
// - Azulejos: área / área pieza con junta × (1 + merma). Merma típica 8–15 % según diseño (Klartext, obrabienhecha, medir.es).
// - Pintura: (m² / rendimiento L/m²) × manos × (1 + merma ~10 %).
// - Mortero lecho: volumen = m² × espesor; cemento/arena por proporción en volumen; sacos según masa.
// - Electricidad: orden ~5–6,5 m de cable por m² de piso (regla gruesa residencial, convertida desde pies/m² EE.UU.).
// - Fontanería: heurística perímetro + puntos × altura; merma tubería ~10 % (guías de estimación).

enum MaterialCalculators {

    // MARK: - Azulejos

    struct TileInput {
        var areaM2: Double
        var tileLengthCm: Double
        var tileWidthCm: Double
        var jointMm: Double
        var wastePercent: Double
        var piecesPerBox: Double
        /// kg de pegamento por m² (típ. 3–6 kg/m² según espesor y sustrato)
        var adhesiveKgPerM2: Double
        /// kg de lechada por m² (orden 0,4–1,5 según ancho junta)
        var groutKgPerM2: Double
    }

    static func estimateTiles(_ input: TileInput) -> (items: [LineItem], notes: [String]) {
        guard input.areaM2 > 0, input.tileLengthCm > 0, input.tileWidthCm > 0 else {
            return ([], ["Introduce área y medida de pieza válidas."])
        }
        let lm = input.tileLengthCm / 100
        let wm = input.tileWidthCm / 100
        let jm = input.jointMm / 1000
        let pieceArea = (lm + jm) * (wm + jm)
        let rawPieces = input.areaM2 / pieceArea
        let withWaste = rawPieces * (1 + max(0, input.wastePercent) / 100)
        let pieces = ceil(withWaste)
        var items: [LineItem] = [
            LineItem(name: "Piezas de cerámica/piso", quantity: pieces, unit: "pza", unitPrice: 0)
        ]
        if input.piecesPerBox > 0 {
            let boxes = ceil(pieces / input.piecesPerBox)
            items.append(LineItem(name: "Cajas (aprox.)", quantity: boxes, unit: "caja", unitPrice: 0))
        }
        let adhesive = input.areaM2 * max(0, input.adhesiveKgPerM2)
        if adhesive > 0 {
            items.append(LineItem(name: "Pegamento / adhesivo", quantity: adhesive, unit: "kg", unitPrice: 0))
        }
        let grout = input.areaM2 * max(0, input.groutKgPerM2)
        if grout > 0 {
            items.append(LineItem(name: "Lechada / junta", quantity: grout, unit: "kg", unitPrice: 0))
        }
        let notes = [
            "Merma recomendada: recto 5–8 %, diagonal 12–15 %. Ajusta según diseño.",
            "Compra del mismo lote para evitar diferencias de tono."
        ]
        return (items, notes)
    }

    // MARK: - Pintura

    struct PaintInput {
        var roomLengthM: Double
        var roomWidthM: Double
        var roomHeightM: Double
        var subtractM2: Double
        var includeCeiling: Bool
        var coats: Double
        /// m² cubiertos por litro y mano (típ. interior 8–12)
        var coverageM2PerLiter: Double
        var wastePercent: Double
    }

    static func estimatePaint(_ input: PaintInput) -> (items: [LineItem], notes: [String]) {
        guard input.roomLengthM > 0, input.roomWidthM > 0, input.roomHeightM > 0 else {
            return ([], ["Introduce largo, ancho y alto de la habitación."])
        }
        let perimeter = 2 * (input.roomLengthM + input.roomWidthM)
        var wallM2 = perimeter * input.roomHeightM
        if input.includeCeiling {
            wallM2 += input.roomLengthM * input.roomWidthM
        }
        wallM2 = max(0, wallM2 - max(0, input.subtractM2))
        guard input.coverageM2PerLiter > 0, input.coats > 0 else {
            return ([], ["Rendimiento y número de manos deben ser mayores que 0."])
        }
        let litersRaw = (wallM2 / input.coverageM2PerLiter) * input.coats
        let liters = litersRaw * (1 + max(0, input.wastePercent) / 100)
        let items = [
            LineItem(name: "Pintura (total aprox.)", quantity: liters, unit: "L", unitPrice: 0),
            LineItem(name: "Superficie pintada (aprox.)", quantity: wallM2, unit: "m²", unitPrice: 0)
        ]
        let notes = [
            "Rendimiento real depende del fabricante y porosidad. Revisa la lata.",
            "Suele aplicarse 2 manos en muros interiores."
        ]
        return (items, notes)
    }

    // MARK: - Mortero / lecho

    struct MortarInput {
        var areaM2: Double
        var thicknessMm: Double
        /// Partes de cemento en la mezcla (ej. 1 en 1:4)
        var cementParts: Double
        /// Partes de arena
        var sandParts: Double
        var bagKg: Double
        /// Factor de volumen seco respecto al húmedo (hormigones ~1,27 típico)
        var dryVolumeFactor: Double
        var cementDensityKgPerM3: Double
    }

    static func estimateMortar(_ input: MortarInput) -> (items: [LineItem], notes: [String]) {
        guard input.areaM2 > 0, input.thicknessMm > 0 else {
            return ([], ["Introduce área y espesor del lecho o capa."])
        }
        let wetM3 = input.areaM2 * (input.thicknessMm / 1000)
        let dryM3 = wetM3 * max(1, input.dryVolumeFactor)
        let totalParts = max(0.0001, input.cementParts + input.sandParts)
        let cementM3 = dryM3 * (input.cementParts / totalParts)
        let sandM3 = dryM3 * (input.sandParts / totalParts)
        let cementKg = cementM3 * input.cementDensityKgPerM3
        let bags = input.bagKg > 0 ? ceil(cementKg / input.bagKg) : 0
        var items: [LineItem] = [
            LineItem(name: "Volumen húmedo (aprox.)", quantity: wetM3, unit: "m³", unitPrice: 0),
            LineItem(name: "Arena (volumen seco aprox.)", quantity: sandM3, unit: "m³", unitPrice: 0),
            LineItem(name: "Cemento (masa aprox.)", quantity: cementKg, unit: "kg", unitPrice: 0)
        ]
        if bags > 0 {
            items.append(LineItem(name: "Sacos de cemento (\(EstimateLocale.formatNumber(input.bagKg, fractionDigits: 0)) kg, redondeo arriba)", quantity: bags, unit: "saco", unitPrice: 0))
        }
        let notes = [
            "Proporciones comunes lecho/pared: 1:3 a 1:6 en volumen según uso.",
            "En obra real el consumo varía con sustrato y mano de albañil."
        ]
        return (items, notes)
    }

    // MARK: - Fontanería (heurística)

    struct PlumbingInput {
        var roomLengthM: Double
        var roomWidthM: Double
        var roomHeightM: Double
        var waterPoints: Int
        var wastePercent: Double
    }

    static func estimatePlumbing(_ input: PlumbingInput) -> (items: [LineItem], notes: [String]) {
        guard input.roomLengthM > 0, input.roomWidthM > 0, input.roomHeightM > 0 else {
            return ([], ["Introduce medidas de la habitación o zona húmeda."])
        }
        let perimeter = 2 * (input.roomLengthM + input.roomWidthM)
        let supplyBase = perimeter * 1.15
        let drops = Double(max(0, input.waterPoints)) * input.roomHeightM * 0.55
        let supplyM = (supplyBase + drops) * (1 + max(0, input.wastePercent) / 100)
        let drainM = (perimeter * 0.45 + input.roomHeightM) * (1 + max(0, input.wastePercent) / 100)
        let fittings = ceil((supplyM + drainM) / 3)
        let items = [
            LineItem(name: "Tubería suministro (aprox.)", quantity: supplyM, unit: "m", unitPrice: 0),
            LineItem(name: "Tubería desagüe PVC (aprox.)", quantity: drainM, unit: "m", unitPrice: 0),
            LineItem(name: "Accesorios/codos (aprox.)", quantity: fittings, unit: "pza", unitPrice: 0)
        ]
        let notes = [
            "Cálculo orientativo para replanteo rápido; mide trazos reales en sitio.",
            "Añade ~10 % de merma en cortes (ajustable arriba)."
        ]
        return (items, notes)
    }

    // MARK: - Electricidad (regla gruesa)

    struct ElectricalInput {
        var roomLengthM: Double
        var roomWidthM: Double
        /// Metros de cable por m² de piso (referencia 5–7)
        var cableMPerFloorM2: Double
        var circuits: Int
        var extraMPerCircuit: Double
    }

    static func estimateElectrical(_ input: ElectricalInput) -> (items: [LineItem], notes: [String]) {
        let floor = max(0, input.roomLengthM * input.roomWidthM)
        guard floor > 0 else {
            return ([], ["Introduce largo y ancho para obtener m² de piso."])
        }
        let cableM = floor * max(0, input.cableMPerFloorM2) + Double(max(0, input.circuits)) * max(0, input.extraMPerCircuit)
        let conduitM = cableM * 0.85
        let boxes = max(4, Int(ceil(floor / 12)))
        let items = [
            LineItem(name: "Cable (aprox. total)", quantity: cableM, unit: "m", unitPrice: 0),
            LineItem(name: "Canalización / conduit (aprox.)", quantity: conduitM, unit: "m", unitPrice: 0),
            LineItem(name: "Cajas de registro / aparato (aprox.)", quantity: Double(boxes), unit: "pza", unitPrice: 0)
        ]
        let notes = [
            "Basado en reglas generales de vivienda; tablero lejos o muchos puntos aumentan cable.",
            "Calibre y tipo de cable deben cumplir norma local (NOM / reglamento)."
        ]
        return (items, notes)
    }
}
