import Foundation
import GRDB

/// Categories (BUSINESS_RULES §2.1 seed plus custom ones). Writes go through the
/// `OutboxWriter`.
struct CategoriesRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter
    let entitlement: EntitlementStore

    private let ids = IDGenerator()

    func observeAll() -> AsyncValueObservation<[CategoryRecord]> { database.observeCategories() }

    func find(_ id: String) async throws -> CategoryRecord? {
        try await database.pool.read { try $0.category(id: id) }
    }

    private func validateName(_ name: String, type: String, exceptId: String? = nil) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { throw ValidationError.nameRequired }
        if trimmed.count > 50 { throw ValidationError.nameTooLong }
        let lowered = trimmed.lowercased()
        let others = try await database.pool.read { try $0.liveCategories() }
        if others.contains(where: {
            $0.id != exceptId && $0.type == type
                && $0.name.trimmingCharacters(in: .whitespaces).lowercased() == lowered
        }) {
            throw ValidationError.nameTaken
        }
    }

    /// Creates a custom category (free plan: at most 5, archived ones count).
    @discardableResult
    func create(
        name: String, type: String, icon: String, color: String, defaultAllocation: String?
    ) async throws -> String {
        try await validateName(name, type: type)
        if type == "expense" && defaultAllocation == nil {
            throw ValidationError.allocationRequired
        }
        if await !entitlement.isPremium() {
            let custom = try await database.pool.read { try $0.customCategoryCount() }
            if custom >= PlanLimits.maxFreeCustomCategories {
                throw PlanLimitError(kind: .categories)
            }
        }
        let id = ids.newID()
        let sortOrder = try await database.pool.read { try $0.maxCategorySortOrder(type: type) } + 1
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        try await writer.write { tx in
            try tx.upsert(
                CategoryRecord(
                    id: id, createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                    serverVersion: nil, syncStatus: "pending", syncError: nil, type: type,
                    name: trimmed, icon: icon, color: color,
                    defaultAllocation: type == "expense" ? defaultAllocation : nil,
                    sortOrder: sortOrder, isDefault: false, isHidden: false, archivedAt: nil))
        }
        return id
    }

    /// Edits a category. The default allocation only affects new transactions; the icon of a
    /// seeded category stays (the fee category is found by it).
    func update(
        _ existing: CategoryRecord, name: String, icon: String, color: String,
        defaultAllocation: String?
    ) async throws {
        try await validateName(name, type: existing.type, exceptId: existing.id)
        var changed = existing
        changed.name = name.trimmingCharacters(in: .whitespaces)
        if !existing.isDefault { changed.icon = icon }
        changed.color = color
        changed.defaultAllocation = existing.type == "expense" ? defaultAllocation : nil
        try await writer.write { [changed] tx in try tx.upsert(changed) }
    }

    func setHidden(_ category: CategoryRecord, hidden: Bool) async throws {
        var changed = category
        changed.isHidden = hidden
        try await writer.write { [changed] tx in try tx.upsert(changed) }
    }

    func setArchived(_ category: CategoryRecord, archived: Bool) async throws {
        try await writer.write { tx in
            var changed = category
            changed.archivedAt = archived ? tx.now : nil
            try tx.upsert(changed)
        }
    }

    /// Stores the new order of one type's categories (drag to reorder).
    func reorder(_ ordered: [CategoryRecord]) async throws {
        try await writer.write { tx in
            for (index, category) in ordered.enumerated() where category.sortOrder != index + 1 {
                var changed = category
                changed.sortOrder = index + 1
                try tx.upsert(changed)
            }
        }
    }

    func isUsed(_ id: String) async throws -> Bool {
        try await database.pool.read { try $0.transactionCount(categoryId: id) } > 0
    }

    /// Permanently deletes a category that no live transaction uses.
    func delete(_ id: String) async throws {
        if try await isUsed(id) { throw RecordInUseError(isAccount: false) }
        try await writer.write { tx in try tx.delete(CategoryRecord.self, id: id) }
    }
}
