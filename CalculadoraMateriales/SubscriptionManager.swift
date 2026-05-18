import Foundation
import StoreKit
import Combine

/// StoreKit 2: suscripción mensual; oferta introductoria gratuita 1 mes (App Store Connect o TradeMaterialsCalculator.storekit).
@MainActor
final class SubscriptionManager: ObservableObject {
    static let subscriptionProductId = "calcobra.pro.monthly"

    @Published private(set) var product: Product?
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var lastErrorMessage: String?
    /// Primera carga de StoreKit terminada (éxito o error), para no mostrar el paywall un frame antes de saber el estado.
    @Published private(set) var hasCompletedInitialLoad: Bool = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await self.listenForTransactionUpdates() }
        Task { await self.loadProductsAndRefreshEntitlements() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProductsAndRefreshEntitlements() async {
        isLoadingProducts = true
        lastErrorMessage = nil
        defer {
            isLoadingProducts = false
            hasCompletedInitialLoad = true
        }
        do {
            let products = try await Product.products(for: [Self.subscriptionProductId])
            product = products.first
            if product == nil {
                lastErrorMessage = "No se encontró el producto \(Self.subscriptionProductId). Crea el producto en App Store Connect o ejecuta con TradeMaterialsCalculator.storekit."
            }
            await refreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.subscriptionProductId {
                active = true
                break
            }
        }
        isSubscribed = active
    }

    private func listenForTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            if case .verified(let transaction) = verificationResult {
                await transaction.finish()
            }
            await refreshEntitlements()
        }
    }

    func purchase() async {
        lastErrorMessage = nil
        guard let product else {
            lastErrorMessage = "Producto no disponible todavía."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                case .unverified(_, let error):
                    lastErrorMessage = error.localizedDescription
                }
            case .userCancelled:
                break
            case .pending:
                lastErrorMessage = "Compra pendiente de aprobación (Ask to Buy o similar)."
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
            await loadProductsAndRefreshEntitlements()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    var subscriptionDisplayPrice: String {
        product?.displayPrice ?? "US$1.99"
    }

    var introductoryOfferDescription: String {
        guard let sub = product?.subscription,
              let intro = sub.introductoryOffer,
              intro.paymentMode == .freeTrial
        else {
            return "Incluye 1 mes gratis si eres elegible (Apple), luego \(subscriptionDisplayPrice) al mes."
        }
        let period = intro.period
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "día" : "días"
        case .week: unit = period.value == 1 ? "semana" : "semanas"
        case .month: unit = period.value == 1 ? "mes" : "meses"
        case .year: unit = period.value == 1 ? "año" : "años"
        @unknown default: unit = "periodo"
        }
        return "Prueba gratis: \(period.value) \(unit). Después: \(subscriptionDisplayPrice) / mes."
    }
}
