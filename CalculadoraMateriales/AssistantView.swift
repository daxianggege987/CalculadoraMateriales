import SwiftUI

struct AssistantView: View {
    @EnvironmentObject private var aiSettings: AISettings
    @EnvironmentObject private var snapshotStore: CalculationSnapshotStore

    @State private var question: String = ""
    @State private var includeSnapshot: Bool = true
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let client = OpenAICompatibleChatClient()

    private var systemPrompt: String {
        """
        Eres un asistente de obra para albañiles, fontaneros y electricistas en América Latina.
        La aplicación solo genera ESTIMACIONES con fórmulas sencillas; tú ayudas a interpretar, \
        listar compras y recordar detalles de sitio.
        Reglas:
        - Respuestas en español, concretas, con listas cortas cuando ayude.
        - No sustituyes a un ingeniero ni a normativa oficial (NOM, reglamentos eléctricos locales, etc.).
        - Si el usuario pide cumplimiento normativo exacto, indica que debe verificar con técnico y reglas vigentes.
        - Si hay contexto numérico de la app, respétalo salvo que detectes un error obvio; entonces explica la duda.
        - Menciona seguridad (EPP, apagar breaker, ventilación) cuando aplique.
        """
    }

    var body: some View {
        Form {
            Section(header: Text("Estado")) {
                if aiSettings.isReadyToCall {
                    Label("API configurada", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Falta clave o URL en Ajustes", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                if snapshotStore.hasSnapshot {
                    Text("Último cálculo: \(snapshotStore.lastTradeTitle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Aún no hay cálculo guardado. Usa «Cálculos» y pulsa Calcular.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Contexto")) {
                Toggle("Incluir último resultado de la app", isOn: $includeSnapshot)
                    .disabled(!snapshotStore.hasSnapshot)
            }

            Section(header: Text("Tu pregunta")) {
                TextEditor(text: $question)
                    .frame(minHeight: 100)
                quickPrompts
            }

            Section {
                Button(action: send) {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Consultando…")
                        }
                    } else {
                        Label("Enviar al modelo", systemImage: "paperplane.fill")
                    }
                }
                .disabled(!aiSettings.isReadyToCall || isLoading || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let err = errorMessage {
                Section {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if !responseText.isEmpty {
                Section(header: Text("Respuesta")) {
                    Text(responseText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            Section(footer: Text("Los datos se envían al proveedor de IA que configuraste. No compartas datos personales de clientes.")) {
                EmptyView()
            }
        }
        .navigationTitle("Asistente IA")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if snapshotStore.hasSnapshot { includeSnapshot = true }
        }
    }

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                promptChip("¿Qué más compro además de la lista?")
                promptChip("Explica el resultado en pocas frases")
                promptChip("¿La merma es razonable para diseño en diagonal?")
                promptChip("Consejos de seguridad en este trabajo")
            }
        }
    }

    private func promptChip(_ text: String) -> some View {
        Button(text) {
            question = text
        }
        .buttonStyle(.bordered)
        .font(.caption)
    }

    private func send() {
        errorMessage = nil
        isLoading = true
        responseText = ""
        let userQ = question.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = ""
        if includeSnapshot, snapshotStore.hasSnapshot {
            body += "Contexto del último cálculo en la app:\n\n"
            body += snapshotStore.lastSummaryText
            body += "\n\n---\n\n"
        }
        body += "Pregunta del usuario:\n\(userQ)"

        Task {
            do {
                let url = try aiSettings.resolvedChatURL()
                guard let key = KeychainHelper.loadAPIKey(), !key.isEmpty else {
                    throw ChatClientError.httpStatus(401, "Sin clave en llavero")
                }
                let text = try await client.complete(
                    url: url,
                    apiKey: key,
                    model: aiSettings.model.trimmingCharacters(in: .whitespacesAndNewlines),
                    systemPrompt: systemPrompt,
                    userContent: body
                )
                await MainActor.run {
                    responseText = text
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct AssistantView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AssistantView()
                .environmentObject(AISettings())
                .environmentObject(CalculationSnapshotStore())
        }
    }
}
