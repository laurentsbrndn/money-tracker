/// A budget warning to show now.
struct BudgetAlert: Sendable, Equatable {
    var allocation: Allocation
    /// 80 or 100 (percent of the goal).
    var level: Int
    var goalAmount: Int64
    var actual: Int64
}

/// What to announce and what to remember (BUSINESS_RULES §4.5): needs and wants warn when they
/// reach 80% and then 100% of their goal, at most once per threshold per month.
struct BudgetAlertPlan: Sendable, Equatable {
    var alerts: [BudgetAlert]
    /// Every threshold up to the announced level, so jumping straight past 80% does not announce
    /// it again later.
    var keysToRemember: Set<String>
}

enum BudgetAlertPolicy {
    /// The key remembered once a threshold has been announced for a month.
    static func key(month: YearMonth, allocation: Allocation, level: Int) -> String {
        "\(month.description)|\(allocation.rawValue)|\(level)"
    }

    static func plan(month: YearMonth, budget: Budget, alreadyAnnounced: Set<String>)
        -> BudgetAlertPlan
    {
        var alerts: [BudgetAlert] = []
        var keys: Set<String> = []
        let buckets: [(Allocation, AllocationResult)] = [
            (.needs, budget.needs), (.wants, budget.wants),
        ]
        for (allocation, result) in buckets {
            guard
                let level = DomainRules.budgetAlertLevel(
                    goalAmount: result.goalAmount, actual: result.actual)
            else { continue }
            let reached = [budgetWarnPercent, budgetLimitPercent].filter { $0 <= level }
            let fresh = reached.filter {
                !alreadyAnnounced.contains(key(month: month, allocation: allocation, level: $0))
            }
            guard let top = fresh.last else { continue }
            alerts.append(
                BudgetAlert(
                    allocation: allocation, level: top, goalAmount: result.goalAmount,
                    actual: result.actual))
            for threshold in reached {
                keys.insert(key(month: month, allocation: allocation, level: threshold))
            }
        }
        return BudgetAlertPlan(alerts: alerts, keysToRemember: keys)
    }
}
