import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var aiSettings: AISettings
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var testMessage: String?
    @State private var testing: Bool = false

    private let client = OpenAICompatibleChatClient()

    var body: some View {
        Form {
            Section(header: Text("Trade Materials Calculator")) {
                if subscriptionManager.isSubscribed {
                    Label("Suscripción activa", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Sin suscripción", systemImage: "lock.fill")
                        .foregroundColor(.secondary)
                }
                Text("Incluye 1 mes gratis (si aplica) y luego \(subscriptionManager.subscriptionDisplayPrice) al mes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Restaurar compras") {
                    Task { await subscriptionManager.restorePurchases() }
                }
                Button("Gestionar suscripción…") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.subheadline)
            }

            Section(header: Text("Proveedor compatible OpenAI")) {
                TextField("URL base (sin /chat/completions)", text: $aiSettings.baseURL)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                TextField("Modelo", text: $aiSettings.model)
                    .autocapitalization(.none)
                SecureField("Clave API (se guarda en llavero)", text: $aiSettings.apiKeyDraft)
                    .textContentType(.password)
                    .autocapitalization(.none)
                Button("Guardar clave en llavero") {
                    _ = aiSettings.saveAPIKeyToKeychain()
                }
                .disabled(aiSettings.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if aiSettings.hasSavedKey {
                    Button("Borrar clave del dispositivo", role: .destructive) {
                        aiSettings.clearAPIKey()
                    }
                }
            }

            Section(header: Text("Conexión")) {
                Button {
                    runTest()
                } label: {
                    if testing {
                        HStack {
                            ProgressView()
                            Text("Probando…")
                        }
                    } else {
                        Label("Probar conexión", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                .disabled(testing || !canTest)

                if let testMessage {
                    Text(testMessage)
                        .font(.caption)
                        .foregroundColor(testMessage.contains("✓") ? .green : .red)
                }
            }

            Section(header: Text("Ejemplos de URL base")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenAI: https://api.openai.com/v1")
                    Text("Groq: https://api.groq.com/openai/v1")
                    Text("Otro: la raíz que exponga POST …/chat/completions")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section(footer: Text("La clave viaja solo al servidor que indiques. No la compartas ni la subas a repositorios. Cumple las políticas de tu proveedor y la ley de protección de datos local.")) {
                EmptyView()
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            aiSettings.reloadKeyFromKeychain()
        }
        .task {
            await subscriptionManager.loadProductsAndRefreshEntitlements()
        }
    }

    private var canTest: Bool {
        let key = KeychainHelper.loadAPIKey() ?? aiSettings.apiKeyDraft
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !aiSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !aiSettings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func runTest() {
        testMessage = nil
        testing = true
        let key = (KeychainHelper.loadAPIKey()).flatMap { $0.isEmpty ? nil : $0 } ?? aiSettings.apiKeyDraft
        Task {
            do {
                let url = try aiSettings.resolvedChatURL()
                let text = try await client.complete(
                    url: url,
                    apiKey: key,
                    model: aiSettings.model.trimmingCharacters(in: .whitespacesAndNewlines),
                    systemPrompt: "Responde únicamente la palabra OK si recibes el mensaje.",
                    userContent: "ping",
                    temperature: 0
                )
                await MainActor.run {
                    testMessage = "✓ Conexión correcta. Respuesta: \(text.prefix(80))"
                    testing = false
                }
            } catch {
                await MainActor.run {
                    testMessage = error.localizedDescription
                    testing = false
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(AISettings())
                .environmentObject(SubscriptionManager())
        }
    }
}
