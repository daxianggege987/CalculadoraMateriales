import Foundation

/// Enlaces legales públicos (Apple) y rutas de documentación incluida en el bundle.
enum LegalLinks {
    /// EULA estándar de Apple para aplicaciones licenciadas (suscripciones / App Store).
    static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Términos generales de los servicios de medios de Apple (referencia).
    static let appleMediaServices = URL(string: "https://www.apple.com/legal/internet-services/itunes/")!

    /// Copia en GitHub Pages (mismo contenido que `docs/`); respaldo si falta el HTML en el bundle.
    static let hostedPrivacyPolicy = URL(string: "https://daxianggege987.github.io/CalculadoraMateriales/privacidad.html")!

    static let hostedSupport = URL(string: "https://daxianggege987.github.io/CalculadoraMateriales/soporte.html")!

    static func bundledPrivacyURL() -> URL? {
        Bundle.main.url(forResource: "privacidad", withExtension: "html", subdirectory: "BundledLegal")
    }

    static func bundledSupportURL() -> URL? {
        Bundle.main.url(forResource: "soporte", withExtension: "html", subdirectory: "BundledLegal")
    }
}
