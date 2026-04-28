//
//  SuperwallRegister.swift
//  surgeapp
//

import OSLog
import SuperwallKit

/// Names must match **Placements** in the Superwall dashboard (exact string).
enum SuperwallPlacements {
    static let campaignTrigger = "campaign_trigger"
    static let upgradeTapped = "upgrade_tapped"
    static let manageSubscriptionTapped = "manage_subscription_tapped"
    /// Add this placement in the Superwall dashboard (exact string) for free-tier quota bypass attempts.
    static let freeTierLimit = "free_tier_limit"
}

private let paywallLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "surgeapp",
    category: "Superwall"
)

/// Registers a placement and presents a paywall when your campaign rules allow it. Uses the `feature` overload
/// from the Superwall docs. Logs **present / skip / error** in Console (filter `Superwall`).
func registerSuperwallPlacement(_ placement: String) {
    let handler = PaywallPresentationHandler()
    handler.onPresent { _ in
        paywallLog.info("Presented: \(placement, privacy: .public)")
    }
    handler.onSkip { reason in
        paywallLog.warning("Skipped [\(placement, privacy: .public)]: \(reason.description, privacy: .public)")
    }
    handler.onError { error in
        paywallLog.error("Error [\(placement, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
    }
    Superwall.shared.register(placement: placement, params: nil, handler: handler) {}
}
