import Foundation

/// Enlaces legales públicos (Apple) y rutas de documentación incluida en el bundle.
enum LegalLinks {
    /// EULA estándar de Apple para aplicaciones licenciadas (suscripciones / App Store).
    static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Términos generales de los servicios de medios de Apple (referencia).
    static let appleMediaServices = URL(string: "https://www.apple.com/legal/internet-services/itunes/")!

    static func bundledPrivacyURL() -> URL? {
        Bundle.main.url(forResource: "privacidad", withExtension: "html", subdirectory: "BundledLegal")
    }

    static func bundledSupportURL() -> URL? {
        Bundle.main.url(forResource: "soporte", withExtension: "html", subdirectory: "BundledLegal")
    }
}
