import SwiftUI

struct ContentView: View {
    private let trades: [TradeKind] = TradeKind.allCases

    var body: some View {
        NavigationView {
            List(trades) { trade in
                NavigationLink(destination: destination(for: trade)) {
                    HStack(spacing: 14) {
                        Image(systemName: trade.systemImage)
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .frame(width: 36, alignment: .center)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trade.title)
                                .font(.headline)
                            Text(trade.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Trade Materials Calculator")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    @ViewBuilder
    private func destination(for trade: TradeKind) -> some View {
        switch trade {
        case .plumbing: PlumbingCalculatorView()
        case .electrical: ElectricalCalculatorView()
        case .tiles: TilesCalculatorView()
        case .paint: PaintCalculatorView()
        case .mortar: MortarCalculatorView()
        }
    }
}

enum TradeKind: String, CaseIterable, Identifiable {
    case plumbing
    case electrical
    case tiles
    case paint
    case mortar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plumbing: return "Fontanería"
        case .electrical: return "Electricidad"
        case .tiles: return "Azulejos / pisos"
        case .paint: return "Pintura"
        case .mortar: return "Cemento y mortero"
        }
    }

    var subtitle: String {
        switch self {
        case .plumbing: return "Tubería aprox. según perímetro y puntos"
        case .electrical: return "Cable por m² de piso (regla gruesa)"
        case .tiles: return "Piezas, cajas, adhesivo y lechada"
        case .paint: return "Litros según m², manos y rendimiento"
        case .mortar: return "Cemento y arena por volumen de lecho"
        }
    }

    var systemImage: String {
        switch self {
        case .plumbing: return "drop.fill"
        case .electrical: return "bolt.fill"
        case .tiles: return "square.grid.3x3.fill"
        case .paint: return "paintbrush.fill"
        case .mortar: return "cube.fill"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CalculationSnapshotStore())
    }
}
