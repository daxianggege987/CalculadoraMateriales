import SwiftUI
import UIKit

private enum LegalSheet: String, Identifiable {
    case privacidad
    case soporte
    var id: String { rawValue }
}

/// Pantalla completa al inicio: sin suscripción activa no se accede al resto de la app.
/// En iPad (`regular` / ancho amplio) el contenido se centra con ancho máximo legible y enlaces en rejilla, evitando la «columna estrecha de iPhone».
struct SubscriptionGateView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var legalSheet: LegalSheet?

    var body: some View {
        GeometryReader { geo in
            let roomy = (horizontalSizeClass == .regular) || (geo.size.width >= 560)
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: roomy ? 28 : 22) {
                        Text("Trade Materials Calculator")
                            .font(roomy ? .system(size: 40, weight: .bold) : .largeTitle.bold())
                        Text("Suscríbete para usar la app: calculadoras de obra, lista de materiales y asistente de IA.")
                            .font(roomy ? .title3 : .body)
                            .foregroundColor(.secondary)
                        Text(subscriptionManager.introductoryOfferDescription)
                            .font(roomy ? .body.weight(.semibold) : .body.weight(.medium))
                        if subscriptionManager.isLoadingProducts {
                            ProgressView("Cargando…")
                                .padding(.vertical, 8)
                        }
                        if let err = subscriptionManager.lastErrorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        legalLinksBlock(roomy: roomy)

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
                        .font(roomy ? .body : .subheadline)
                        .padding(.top, 4)

                        Text("La prueba gratis y el cobro los gestiona Apple. Puedes cancelar en Ajustes del sistema → [tu nombre] → Suscripciones.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 12)

                        Text("Tras activar la suscripción, la app no volverá a bloquearte el acceso mientras la suscripción siga vigente con Apple.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: roomy ? 860 : .infinity, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, roomy ? 40 : 24)
                    .padding(.vertical, roomy ? 36 : 20)
                }
            }
        }
        .fullScreenCover(item: $legalSheet) { sheet in
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

    @ViewBuilder
    private func legalLinksBlock(roomy: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información legal")
                .font(roomy ? .title2.weight(.semibold) : .headline)

            if roomy {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    legalLinkButton(title: "Política de privacidad", systemImage: "hand.raised.fill") {
                        if LegalLinks.bundledPrivacyURL() != nil {
                            legalSheet = .privacidad
                        } else {
                            openHTTPSExternally(LegalLinks.hostedPrivacyPolicy)
                        }
                    }
                    legalLinkButton(title: "Soporte técnico", systemImage: "questionmark.circle.fill") {
                        if LegalLinks.bundledSupportURL() != nil {
                            legalSheet = .soporte
                        } else {
                            openHTTPSExternally(LegalLinks.hostedSupport)
                        }
                    }
                    legalLinkButton(title: "EULA estándar de Apple (suscripciones)", systemImage: "doc.text.fill") {
                        openHTTPSExternally(LegalLinks.appleStandardEULA)
                    }
                    legalLinkButton(title: "Términos de servicios de medios (Apple)", systemImage: "link") {
                        openHTTPSExternally(LegalLinks.appleMediaServices)
                    }
                }
            } else {
                legalLinkButton(title: "Política de privacidad", systemImage: "hand.raised.fill") {
                    if LegalLinks.bundledPrivacyURL() != nil {
                        legalSheet = .privacidad
                    } else {
                        openHTTPSExternally(LegalLinks.hostedPrivacyPolicy)
                    }
                }

                legalLinkButton(title: "Soporte técnico", systemImage: "questionmark.circle.fill") {
                    if LegalLinks.bundledSupportURL() != nil {
                        legalSheet = .soporte
                    } else {
                        openHTTPSExternally(LegalLinks.hostedSupport)
                    }
                }

                legalLinkButton(title: "EULA estándar de Apple (suscripciones)", systemImage: "doc.text.fill") {
                    openHTTPSExternally(LegalLinks.appleStandardEULA)
                }

                legalLinkButton(title: "Términos de servicios de medios (Apple)", systemImage: "link") {
                    openHTTPSExternally(LegalLinks.appleMediaServices)
                }
            }

            Text("Al suscribirte aceptas el cobro recurrente de Apple tras la prueba gratuita (si aplica), el EULA estándar de licencia y los términos aplicables de Apple.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func legalLinkButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundColor(Color.accentColor)
    }

    /// Abre Safari (o el navegador predeterminado). Más fiable que `EnvironmentValues.openURL` en algunas pantallas a pantalla completa.
    private func openHTTPSExternally(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct SubscriptionGateView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionGateView()
            .environmentObject(SubscriptionManager())
    }
}
