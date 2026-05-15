import SwiftUI

private enum LegalSheet: String, Identifiable {
    case privacidad
    case soporte
    var id: String { rawValue }
}

/// Pantalla completa al inicio: sin suscripción activa no se accede al resto de la app.
struct SubscriptionGateView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.openURL) private var openURL

    @State private var legalSheet: LegalSheet?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("CalcObra")
                        .font(.largeTitle.bold())
                    Text("Suscríbete para usar la app: calculadoras de obra, lista de materiales y asistente de IA.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Text(subscriptionManager.introductoryOfferDescription)
                        .font(.body.weight(.medium))
                    if subscriptionManager.isLoadingProducts {
                        ProgressView("Cargando…")
                            .padding(.vertical, 8)
                    }
                    if let err = subscriptionManager.lastErrorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    legalLinksBlock

                    Button {
                        Task { await subscriptionManager.purchase() }
                    } label: {
                        Label("Suscribirse y continuar", systemImage: "cart.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(subscriptionManager.product == nil || subscriptionManager.isLoadingProducts)

                    Button("Ya estoy suscrito — restaurar compras") {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    .font(.subheadline)
                    .padding(.top, 4)

                    Text("La prueba gratis y el cobro los gestiona Apple. Puedes cancelar en Ajustes del sistema → [tu nombre] → Suscripciones.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 12)

                    Text("Tras activar la suscripción, la app no volverá a bloquearte el acceso mientras la suscripción siga vigente con Apple.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $legalSheet) { sheet in
            NavigationView {
                BundledLegalWebView(fileName: sheet == .privacidad ? "privacidad" : "soporte")
                    .navigationTitle(sheet == .privacidad ? "Privacidad" : "Soporte")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { legalSheet = nil }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
    }

    private var legalLinksBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información legal")
                .font(.headline)
            Button {
                if LegalLinks.bundledPrivacyURL() != nil {
                    legalSheet = .privacidad
                }
            } label: {
                Label("Política de privacidad", systemImage: "hand.raised.fill")
            }
            .disabled(LegalLinks.bundledPrivacyURL() == nil)

            Button {
                if LegalLinks.bundledSupportURL() != nil {
                    legalSheet = .soporte
                }
            } label: {
                Label("Soporte técnico", systemImage: "questionmark.circle.fill")
            }
            .disabled(LegalLinks.bundledSupportURL() == nil)

            Button {
                openURL(LegalLinks.appleStandardEULA)
            } label: {
                Label("EULA estándar de Apple (suscripciones)", systemImage: "doc.text.fill")
            }

            Button {
                openURL(LegalLinks.appleMediaServices)
            } label: {
                Label("Términos de servicios de medios (Apple)", systemImage: "link")
            }

            Text("Al suscribirte aceptas el cobro recurrente de Apple tras la prueba gratuita (si aplica), el EULA estándar de licencia y los términos aplicables de Apple.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct SubscriptionGateView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionGateView()
            .environmentObject(SubscriptionManager())
    }
}
