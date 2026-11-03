/// How a bucket ended against its goal.
enum EvaluationOutcome: Sendable, Equatable {
    /// Needs/wants stayed within the goal, or savings reached it.
    case good
    /// Needs/wants went over the goal, or savings fell short of it.
    case bad
    /// No goal amount to compare with (no goal, or no income basis).
    case unknown
}

struct AllocationEvaluation: Sendable, Equatable {
    var allocation: Allocation
    var outcome: EvaluationOutcome
}

extension MonthBudget {
    private static let allAllocations: [Allocation] = [.needs, .wants, .savings]

    /// The month-end evaluation card (APP_FLOWS Flow 6 step 3): needs and wants should stay at or
    /// under their goal, savings should reach it.
    var evaluation: [AllocationEvaluation] {
        Self.allAllocations.map { AllocationEvaluation(allocation: $0, outcome: outcome($0)) }
    }

    private func outcome(_ allocation: Allocation) -> EvaluationOutcome {
        let result = result(of: allocation)
        if result.goalAmount <= 0 { return .unknown }
        let reached = result.actual >= result.goalAmount
        let good = allocation == .savings ? reached : result.actual <= result.goalAmount
        return good ? .good : .bad
    }

    /// Whether the evaluation card is shown: the month is over, or it is within the last 3 days
    /// of the month.
    var showsEvaluation: Bool {
        asOf > month.last || asOf.days(since: month.last) >= -2
    }
}
