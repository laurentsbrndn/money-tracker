/// The transactions of one calendar day with the day's net amount (income minus expense of
/// transactions that count, BUSINESS_RULES §3).
struct DayGroup: Identifiable, Equatable {
    let date: CivilDate
    let transactions: [TransactionRecord]
    let net: Int64

    var id: CivilDate { date }

    /// Groups `rows` (already newest first) by `transaction_date`.
    static func group(_ rows: [TransactionRecord], asOf: CivilDate) -> [DayGroup] {
        var groups: [DayGroup] = []
        var bucket: [TransactionRecord] = []
        var current = rows.first?.transactionDate

        func flush() {
            guard let current, !bucket.isEmpty else { return }
            var net: Int64 = 0
            for row in bucket {
                let tx = row.domain
                guard DomainRules.counts(tx, asOf: asOf) else { continue }
                switch tx.type {
                case .income: net += tx.amount
                case .expense: net -= tx.amount
                case .transfer, .adjustment: break
                }
            }
            groups.append(DayGroup(date: current, transactions: bucket, net: net))
        }

        for row in rows {
            if row.transactionDate != current {
                flush()
                current = row.transactionDate
                bucket = []
            }
            bucket.append(row)
        }
        flush()
        return groups
    }
}
