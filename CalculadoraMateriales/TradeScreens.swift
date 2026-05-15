import SwiftUI

// MARK: - Compartidos

private func parseDouble(_ text: String) -> Double {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
    return Double(normalized) ?? 0
}

struct LabeledField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct EstimateDisclaimer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Solo estimación", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundColor(.orange)
            Text("Cálculos orientativos para obra. No sustituye mediciones en sitio, proyecto ejecutivo ni normativa local (electricidad, desagües, etc.). Verifica cantidades con tu proveedor.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

struct LineItemsResultSection: View {
    let items: [LineItem]
    let currencyCode: String
    @Binding var unitPrices: [UUID: Double]

    private func priceBinding(for id: UUID, default defaultPrice: Double) -> Binding<Double> {
        Binding(
            get: { unitPrices[id] ?? defaultPrice },
            set: { unitPrices[id] = $0 }
        )
    }

    private func resolvedUnitPrice(for item: LineItem) -> Double {
        unitPrices[item.id] ?? PricingHints.defaultUnitPrice(for: item.name)
    }

    private var grandTotal: Double {
        items.reduce(0) { $0 + $1.quantity * resolvedUnitPrice(for: $1) }
    }

    var body: some View {
        Section(header: Text("Lista de materiales"), footer: Group {
            if grandTotal > 0 {
                Text("Total estimado: \(EstimateLocale.formatCurrency(grandTotal, code: currencyCode))")
                    .font(.subheadline.bold())
            }
        }) {
            ForEach(items) { item in
                let defaultP = PricingHints.defaultUnitPrice(for: item.name)
                let unitP = priceBinding(for: item.id, default: defaultP)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.subheadline.bold())
                    HStack {
                        Text("\(EstimateLocale.formatNumber(item.quantity)) \(item.unit)")
                            .foregroundColor(.secondary)
                        Spacer()
                        if item.quantity > 0 && unitP.wrappedValue > 0 {
                            Text(EstimateLocale.formatCurrency(item.quantity * unitP.wrappedValue, code: currencyCode))
                                .font(.subheadline.bold())
                        }
                    }
                    HStack {
                        Text("Precio unit.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("0", value: unitP, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Azulejos

struct TilesCalculatorView: View {
    @EnvironmentObject private var snapshotStore: CalculationSnapshotStore
    @State private var useDirectArea = false
    @State private var lengthM = "4"
    @State private var widthM = "3"
    @State private var areaM2 = "12"
    @State private var tileLcm = "60"
    @State private var tileWcm = "60"
    @State private var jointMm = "2"
    @State private var waste = "10"
    @State private var perBox = "6"
    @State private var adhesiveKgM2 = "4"
    @State private var groutKgM2 = "0.5"
    @State private var currencyCode = DefaultUnitPricing.currencyCode
    @State private var items: [LineItem] = []
    @State private var notes: [String] = []
    @State private var unitPrices: [UUID: Double] = [:]

    var body: some View {
        Form {
            EstimateDisclaimer()
            Section(header: Text("Superficie")) {
                Toggle("Introducir m² directamente", isOn: $useDirectArea)
                if useDirectArea {
                    LabeledField(title: "Área total (m²)", text: $areaM2)
                } else {
                    LabeledField(title: "Largo habitación (m)", text: $lengthM)
                    LabeledField(title: "Ancho habitación (m)", text: $widthM)
                }
            }
            Section(header: Text("Pieza y junta")) {
                LabeledField(title: "Largo pieza (cm)", text: $tileLcm)
                LabeledField(title: "Ancho pieza (cm)", text: $tileWcm)
                LabeledField(title: "Junta (mm)", text: $jointMm)
                LabeledField(title: "Merma (%)", text: $waste)
                LabeledField(title: "Piezas por caja (0 si no aplica)", text: $perBox)
            }
            Section(header: Text("Pegamento y lechada")) {
                LabeledField(title: "Adhesivo (kg por m²)", text: $adhesiveKgM2)
                LabeledField(title: "Lechada (kg por m²)", text: $groutKgM2)
            }
            Section {
                Button("Calcular") { compute() }
                    .font(.headline)
            }
            if !notes.isEmpty {
                Section(header: Text("Notas")) {
                    ForEach(notes, id: \.self) { Text($0).font(.caption) }
                }
            }
            if !items.isEmpty {
                LineItemsResultSection(items: items, currencyCode: currencyCode, unitPrices: $unitPrices)
                ShareEstimateSection(
                    tradeTitle: "Azulejos / pisos",
                    items: items,
                    notes: notes,
                    currencyCode: currencyCode,
                    unitPrices: unitPrices
                )
            }
        }
        .navigationTitle("Azulejos / pisos")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resolvedArea() -> Double {
        if useDirectArea { return parseDouble(areaM2) }
        return parseDouble(lengthM) * parseDouble(widthM)
    }

    private func compute() {
        let input = MaterialCalculators.TileInput(
            areaM2: resolvedArea(),
            tileLengthCm: parseDouble(tileLcm),
            tileWidthCm: parseDouble(tileWcm),
            jointMm: parseDouble(jointMm),
            wastePercent: parseDouble(waste),
            piecesPerBox: parseDouble(perBox),
            adhesiveKgPerM2: parseDouble(adhesiveKgM2),
            groutKgPerM2: parseDouble(groutKgM2)
        )
        let result = MaterialCalculators.estimateTiles(input)
        var list = result.items
        let a = resolvedArea()
        if a > 0 {
            list.insert(
                LineItem(name: "Área revestida (referencia compra)", quantity: a, unit: "m²", unitPrice: 0),
                at: 0
            )
        }
        items = list
        notes = result.notes
        unitPrices = [:]
        if !items.isEmpty {
            snapshotStore.record(
                tradeTitle: "Azulejos / pisos",
                items: items,
                notes: notes,
                currencyCode: currencyCode,
                unitPrices: unitPrices
            )
        }
    }
}

// MARK: - Pintura

struct PaintCalculatorView: View {
    @EnvironmentObject private var snapshotStore: CalculationSnapshotStore
    @State private var lengthM = "4"
    @State private var widthM = "3"
    @State private var heightM = "2.6"
    @State private var subtractM2 = "4"
    @State private var includeCeiling = false
    @State private var coats = "2"
    @State private var coverage = "10"
    @State private var waste = "10"
    @State private var currencyCode = DefaultUnitPricing.currencyCode
    @State private var items: [LineItem] = []
    @State private var notes: [String] = []
    @State private var unitPrices: [UUID: Double] = [:]

    var body: some View {
        Form {
            EstimateDisclaimer()
            Section(header: Text("Habitación")) {
                LabeledField(title: "Largo (m)", text: $lengthM)
                LabeledField(title: "Ancho (m)", text: $widthM)
                LabeledField(title: "Alto (m)", text: $heightM)
                LabeledField(title: "Restar puertas/ventanas (m²)", text: $subtractM2)
                Toggle("Incluir techo", isOn: $includeCeiling)
            }
            Section(header: Text("Pintura")) {
                LabeledField(title: "Manos / capas", text: $coats)
                LabeledField(title: "Rendimiento (m² por litro y mano)", text: $coverage)
                LabeledField(title: "Merma extra (%)", text: $waste)
            }
            Section {
                Button("Calcular") { compute() }
                    .font(.headline)
            }
            if !notes.isEmpty {
                Section(header: Text("Notas")) {
                    ForEach(notes, id: \.self) { Text($0).font(.caption) }
                }
            }
            if !items.isEmpty {
                LineItemsResultSection(items: items, currencyCode: currencyCode, unitPrices: $unitPrices)
                ShareEstimateSection(
                    tradeTitle: "Pintura",
                    items: items,
                    notes: notes,
                    currencyCode: currencyCode,
                    unitPrices: unitPrices
                )
            }
        }
        .navigationTitle("Pintura")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func compute() {
        let input = MaterialCalculators.PaintInput(
            roomLengthM: parseDouble(lengthM),
            roomWidthM: parseDouble(widthM),
            roomHeightM: parseDouble(heightM),
            subtractM2: parseDouble(subtractM2),
            includeCeiling: includeCeiling,
            coats: parseDouble(coats),
            coverageM2PerLiter: parseDouble(coverage),
            wastePercent: parseDouble(waste)
        )
        let result = MaterialCalculators.estimatePaint(input)
        items = result.items
        notes = result.notes
        unitPrices = [:]
        if !items.isEmpty {
            snapshotStore.record(
                tradeTitle: "Pintura",
                items: items,
                notes: notes,
                currencyCode: currencyCode,
                unitPrices: unitPrices
            )
        }
    }
}

// MARK: - Mortero

struct MortarCalculatorView: View {
    @EnvironmentObject private var snapshotStore: CalculationSnapshotStore
    @State private var areaM2 = "12"
    @State private var thicknessMm = "20"
    @State private var cementPart = "1"
    @State private var sandPart = "4"
    @State private var bagKg = "50"
    @State private var dryFactor = "1.27"
    @State private var cementDensity = "1440"
    @State private var currencyCode = DefaultUnitPricing.currencyCode
    @State private var items: [LineItem] = []
    @State private var notes: [String] = []
    @State private var unitPrices: [UUID: Double] = [:]

    var body: some View {
        Form {
            EstimateDisclaimer()
            Section(header: Text("Lecho o capa")) {
                LabeledField(title: "Área (m²)", text: $areaM2)
                LabeledField(title: "Espesor (mm)", text: $thicknessMm)
            }
            Section(header: Text("Mezcla (volumen seco)")) {
                LabeledField(title: "Partes cemento", text: $cementPart, keyboard: .numbersAndPunctuation)
                LabeledField(title: "Partes arena", text: $sandPart, keyboard: .numbersAndPunctuation)
                LabeledField(title: "Peso saco cemento (kg)", text: $bagKg)
                LabeledField(title: "Factor volumen seco / húmedo", text: $dryFactor)
                LabeledField(title: "Densidad cemento (kg/m³)", text: $cementDensity)
            }
            Section {
                Button("Calcular") { compute() }
                    .font(.headline)
            }
            if !notes.isEmpty {
                Section(header: Text("Notas")) {
                    ForEach(notes, id: \.self) { Text($0).font(.caption) }
                }
            }
            if !items.isEmpty {
                LineItemsResultSection(items: items, currencyCode: currencyCode, unitPrices: $unitPrices)
                ShareEstimateSection(
                    tradeTitle: "Cemento y mortero",
                    items: items,
                    notes: notes,
                    currencyCode: currencyCode,
                    unitPrices: unitPrices
                )
            }
        }
        .navigationTitle("Cemento y mortero")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func compute() {
        let input = MaterialCalculators.MortarInput(
            areaM2: parseDouble(areaM2),
            thicknessMm: parseDouble(thicknessMm),
            cementParts: parseDouble(cementPart),
            sandParts: parseDouble(sandPart),
            bagKg: parseDouble(bagKg),
            dryVolumeFactor: parseDouble(dryFactor),
            cementDensityKgPerM3: parseDouble(cementDensity)
        )
        let result = MaterialCalculators.estimateMortar(input)
        items = result.items
        notes = result.notes
        unitPrices = [:]
        if !items.isEmpty {
            snapshotStore.record(
                tradeTitle: "Cemento y mortero",
                items: items,
                notes: notes,
                currencyCode: currencyCode,
                unitPrices: unitPrices
            )
        }
    }
}

// MARK: - Fontanería

struct PlumbingCalculatorView: View {
    @EnvironmentObject private var snapshotStore: CalculationSnapshotStore
    @State private var lengthM = "2.5"
    @State private var widthM = "2"
    @State private var heightM = "2.6"
    @State private var points = "4"
    @State private var waste = "10"
    @State private var currencyCode = DefaultUnitPricing.currencyCode
    @State private var items: [LineItem] = []
    @State private var notes: [String] = []
    @State private var unitPrices: [UUID: Double] = [:]

    var body: some View {
        Form {
            EstimateDisclaimer()
            Section(header: Text("Zona (baño/cocina)")) {
                LabeledField(title: "Largo (m)", text: $lengthM)
                LabeledField(title: "Ancho (m)", text: $widthM)
                LabeledField(title: "Alto (m)", text: $heightM)
                LabeledField(title: "Puntos de agua (lavabo, WC, etc.)", text: $points, keyboard: .numberPad)
                LabeledField(title: "Merma tubería (%)", text: $waste)
            }
            Section {
                Button("Calcular") { compute() }
                    .font(.headline)
            }
            if !notes.isEmpty {
                Section(header: Text("Notas")) {
                    ForEach(notes, id: \.self) { Text($0).font(.caption) }
                }
            }
            if !items.isEmpty {
                LineItemsResultSection(items: items, currencyCode: currencyCode, unitPrices: $unitPrices)
                ShareEstimateSection(
                    tradeTitle: "Fontanería",
                    items: items,
                    notes: notes,
                    currencyCode: currencyCode,
                    unitPrices: unitPrices
                )
            }
        }
        .navigationTitle("Fontanería")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func compute() {
        let input = MaterialCalculators.PlumbingInput(
            roomLengthM: parseDouble(lengthM),
            roomWidthM: parseDouble(widthM),
            roomHeightM: parseDouble(heightM),
            waterPoints: Int(parseDouble(points)),
            wastePercent: parseDouble(waste)
        )
        let result = MaterialCalculators.estimatePlumbing(input)
        items = result.items
        notes = result.notes
        unitPrices = [:]
        if !items.isEmpty {
            snapshotStore.record(
                tradeTitle: "Fontanería",
                items: items,
                notes: notes,
                currencyCode: currencyCode,
                unitPrices: unitPrices
            )
        }
    }
}

// MARK: - Electricidad

struct ElectricalCalculatorView: View {
    @EnvironmentObject private var snapshotStore: CalculationSnapshotStore
    @State private var lengthM = "4"
    @State private var widthM = "3"
    @State private var cablePerM2 = "5.5"
    @State private var circuits = "2"
    @State private var extraPerCircuit = "15"
    @State private var currencyCode = DefaultUnitPricing.currencyCode
    @State private var items: [LineItem] = []
    @State private var notes: [String] = []
    @State private var unitPrices: [UUID: Double] = [:]

    var body: some View {
        Form {
            EstimateDisclaimer()
            Section(header: Text("Espacio")) {
                LabeledField(title: "Largo (m)", text: $lengthM)
                LabeledField(title: "Ancho (m)", text: $widthM)
            }
            Section(header: Text("Regla gruesa")) {
                LabeledField(title: "Cable (m por m² de piso)", text: $cablePerM2)
                LabeledField(title: "Circuitos adicionales", text: $circuits, keyboard: .numberPad)
                LabeledField(title: "Metros extra por circuito", text: $extraPerCircuit)
            }
            Section {
                Button("Calcular") { compute() }
                    .font(.headline)
            }
            if !notes.isEmpty {
                Section(header: Text("Notas")) {
                    ForEach(notes, id: \.self) { Text($0).font(.caption) }
                }
            }
            if !items.isEmpty {
                LineItemsResultSection(items: items, currencyCode: currencyCode, unitPrices: $unitPrices)
                ShareEstimateSection(
                    tradeTitle: "Electricidad",
                    items: items,
                    notes: notes,
                    currencyCode: currencyCode,
                    unitPrices: unitPrices
                )
            }
        }
        .navigationTitle("Electricidad")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func compute() {
        let input = MaterialCalculators.ElectricalInput(
            roomLengthM: parseDouble(lengthM),
            roomWidthM: parseDouble(widthM),
            cableMPerFloorM2: parseDouble(cablePerM2),
            circuits: Int(parseDouble(circuits)),
            extraMPerCircuit: parseDouble(extraPerCircuit)
        )
        let result = MaterialCalculators.estimateElectrical(input)
        items = result.items
        notes = result.notes
        unitPrices = [:]
        if !items.isEmpty {
            snapshotStore.record(
                tradeTitle: "Electricidad",
                items: items,
                notes: notes,
                currencyCode: currencyCode,
                unitPrices: unitPrices
            )
        }
    }
}
