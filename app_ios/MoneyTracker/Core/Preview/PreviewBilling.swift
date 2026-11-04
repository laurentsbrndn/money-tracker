#if DEBUG
    /// A store that needs no network or key: previews of the paywall show these two packages.
    struct PreviewBilling: BillingProviding {
        var isAvailable: Bool { true }

        func configure(userID: String?) async {}
        func syncUser(_ userID: String?) async {}

        func loadPackages() async throws -> [PaywallPackage] {
            [
                PaywallPackage(
                    id: "$rc_monthly", period: .monthly, priceText: "Rp49.000", hasTrial: false,
                    title: "Premium bulanan"),
                PaywallPackage(
                    id: "$rc_annual", period: .yearly, priceText: "Rp399.000", hasTrial: true,
                    title: "Premium tahunan"),
            ]
        }

        func purchase(packageID: String, userID: String) async throws -> PurchaseOutcome {
            .cancelled
        }

        func restore(userID: String) async throws {}
    }
#endif
