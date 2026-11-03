import GRDB

extension Database {
    func category(id: String) throws -> CategoryRecord? {
        try CategoryRecord.fetchOne(self, key: id)
    }

    /// Live categories (hidden and archived included), expense before income, in list order.
    func liveCategories() throws -> [CategoryRecord] {
        try CategoryRecord.filter(Column("deleted_at") == nil)
            .order(Column("type"), Column("sort_order")).fetchAll(self)
    }

    /// Custom categories (not seeded) that are not deleted; archived ones still count towards
    /// the free-plan limit (BUSINESS_RULES §6).
    func customCategoryCount() throws -> Int {
        try CategoryRecord.filter(Column("deleted_at") == nil && Column("is_default") == false)
            .fetchCount(self)
    }

    func maxCategorySortOrder(type: String) throws -> Int {
        try Int.fetchOne(
            self, sql: "SELECT MAX(sort_order) FROM categories WHERE type = ?", arguments: [type])
            ?? 0
    }

    /// The seeded fee category used for transfer admin fees (BUSINESS_RULES §2.1).
    func feeCategory() throws -> CategoryRecord? {
        try CategoryRecord
            .filter(
                Column("deleted_at") == nil && Column("icon") == "fee"
                    && Column("is_default") == true
            )
            .fetchOne(self)
    }
}

extension AppDatabase {
    func observeCategories() -> AsyncValueObservation<[CategoryRecord]> {
        ValueObservation.tracking { try $0.liveCategories() }.values(in: pool)
    }
}
