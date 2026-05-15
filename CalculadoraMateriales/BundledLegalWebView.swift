import SwiftUI
import WebKit

/// Muestra HTML empaquetado en `BundledLegal/` (copia de `docs/` en el repositorio).
struct BundledLegalWebView: UIViewRepresentable {
    let fileName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        if let url = Bundle.main.url(forResource: fileName, withExtension: "html", subdirectory: "BundledLegal") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
