import Foundation
import Combine

final class AISettings: ObservableObject {
    private enum Keys {
        static let baseURL = "ai_base_url"
        static let model = "ai_model"
    }

    /// Se incrementa al guardar/borrar clave para forzar refresco de vistas.
    @Published private(set) var keychainRevision: Int = 0

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Keys.baseURL) }
    }

    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }

    /// Solo en memoria hasta guardar; al cargar la vista de ajustes se rellena desde Keychain.
    @Published var apiKeyDraft: String = ""

    init() {
        let d = UserDefaults.standard
        self.baseURL = d.string(forKey: Keys.baseURL) ?? "https://api.openai.com/v1"
        self.model = d.string(forKey: Keys.model) ?? "gpt-4o-mini"
    }

    var hasSavedKey: Bool {
        _ = keychainRevision
        if let k = KeychainHelper.loadAPIKey(), !k.isEmpty { return true }
        return false
    }

    func reloadKeyFromKeychain() {
        apiKeyDraft = KeychainHelper.loadAPIKey() ?? ""
    }

    @discardableResult
    func saveAPIKeyToKeychain() -> Bool {
        let trimmed = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let ok = KeychainHelper.saveAPIKey(trimmed)
        if ok { keychainRevision += 1 }
        return ok
    }

    func clearAPIKey() {
        KeychainHelper.deleteAPIKey()
        apiKeyDraft = ""
        keychainRevision += 1
    }

    var isReadyToCall: Bool {
        _ = keychainRevision
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = KeychainHelper.loadAPIKey() ?? ""
        return !trimmed.isEmpty && !key.isEmpty && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func resolvedChatURL() throws -> URL {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s + "/chat/completions") else {
            throw ChatClientError.invalidURL
        }
        return url
    }
}

enum ChatClientError: LocalizedError {
    case invalidURL
    case httpStatus(Int, String)
    case emptyResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL base no es válida. Ejemplo: https://api.openai.com/v1"
        case .httpStatus(let code, let body):
            if code == 401 {
                return "API rechazó la clave (401). Revisa el token o permisos."
            }
            return "Error HTTP \(code): \(body.prefix(200))"
        case .emptyResponse:
            return "El modelo no devolvió texto."
        case .decoding:
            return "No se pudo leer la respuesta del servidor."
        }
    }
}

struct OpenAICompatibleChatClient {

    func complete(
        url: URL,
        apiKey: String,
        model: String,
        systemPrompt: String,
        userContent: String,
        temperature: Double = 0.35
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ChatClientError.emptyResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ChatClientError.httpStatus(http.statusCode, text)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw ChatClientError.emptyResponse
        }
        return text
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable {
        let message: Message
    }
    struct Message: Decodable {
        let content: String?
    }
}
