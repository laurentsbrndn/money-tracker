import Foundation
import RevenueCat

/// The only file that imports the RevenueCat SDK (FRONTEND_IOS §4.4): it signs the server user
/// in and out, lists the packages, buys, and restores. It never answers "is the user premium".
actor BillingService: BillingProviding {
    private let apiKey: String
    private var configured = false
    private var busy = false
    private var packages: [String: Package] = [:]

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    var isAvailable: Bool { configured }

    func configure(userID: String?) async {
        guard !apiKey.isEmpty, !configured else { return }
        Purchases.configure(withAPIKey: apiKey, appUserID: userID)
        configured = true
    }

    func syncUser(_ userID: String?) async {
        guard configured else { return }
        do {
            if let userID {
                if Purchases.shared.appUserID != userID { _ = try await Purchases.shared.logIn(userID) }
            } else if !Purchases.shared.isAnonymous {
                // `logOut` on an anonymous customer is an error the SDK raises, so it is skipped.
                _ = try await Purchases.shared.logOut()
            }
        } catch {
            // Retried by the next call (the next session change, or before a purchase).
        }
    }

    func loadPackages() async throws -> [PaywallPackage] {
        try requireAvailable()
        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            throw BillingError(failure: Self.failure(of: error))
        }
        guard let current = offerings.current, !current.availablePackages.isEmpty else {
            throw BillingError(failure: .noProducts)
        }
        packages = Dictionary(
            uniqueKeysWithValues: current.availablePackages.map { ($0.identifier, $0) })
        return current.availablePackages.map(Self.paywallPackage).sorted { $0.period < $1.period }
    }

    func purchase(packageID: String, userID: String) async throws -> PurchaseOutcome {
        try requireAvailable()
        guard let package = packages[packageID] else {
            throw BillingError(failure: .productUnavailable)
        }
        return try await guarded {
            try await self.ensureUser(userID)
            do {
                let result = try await Purchases.shared.purchase(package: package)
                return result.userCancelled ? .cancelled : .purchased
            } catch {
                switch Self.code(of: error) {
                case .purchaseCancelledError: return .cancelled
                case .paymentPendingError: return .pending
                // Already owned: the entitlement may simply not have reached the server yet,
                // which the caller finds out by asking the server.
                case .productAlreadyPurchasedError: return .purchased
                default: throw BillingError(failure: Self.failure(of: error))
                }
            }
        }
    }

    func restore(userID: String) async throws {
        try requireAvailable()
        try await guarded {
            try await self.ensureUser(userID)
            do {
                _ = try await Purchases.shared.restorePurchases()
            } catch {
                throw BillingError(failure: Self.failure(of: error))
            }
        }
    }

    // MARK: - Helpers

    private func guarded<T: Sendable>(_ action: () async throws -> T) async throws -> T {
        if busy { throw BillingError(failure: .busy) }
        busy = true
        defer { busy = false }
        return try await action()
    }

    private func ensureUser(_ userID: String) async throws {
        guard Purchases.shared.appUserID != userID else { return }
        do {
            _ = try await Purchases.shared.logIn(userID)
        } catch {
            let failure = Self.failure(of: error)
            throw BillingError(failure: failure == .network ? .network : .accountLink)
        }
    }

    private func requireAvailable() throws {
        if !configured { throw BillingError(failure: .unavailable) }
    }

    private static func paywallPackage(_ package: Package) -> PaywallPackage {
        let product = package.storeProduct
        let period: PaywallPeriod
        switch package.packageType {
        case .monthly: period = .monthly
        case .annual: period = .yearly
        default: period = .other
        }
        return PaywallPackage(
            id: package.identifier, period: period, priceText: product.localizedPriceString,
            hasTrial: product.introductoryDiscount?.paymentMode == .freeTrial,
            title: product.localizedTitle)
    }

    private static func code(of error: any Error) -> ErrorCode? {
        ErrorCode(rawValue: (error as NSError).code)
    }

    private static func failure(of error: any Error) -> BillingFailure {
        switch code(of: error) {
        case .networkError, .unknownBackendError, .unexpectedBackendResponseError,
            .offlineConnectionError:
            return .network
        case .productNotAvailableForPurchaseError, .purchaseInvalidError, .ineligibleError:
            return .productUnavailable
        case .purchaseNotAllowedError, .storeProblemError, .insufficientPermissionsError:
            return .notAllowed
        case .operationAlreadyInProgressForProductError:
            return .busy
        case .configurationError, .invalidCredentialsError:
            return .unavailable
        default:
            return .unknown
        }
    }
}
