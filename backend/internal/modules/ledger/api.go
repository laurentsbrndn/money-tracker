// Package ledger owns transactions. Other modules use only this file.
package ledger

import (
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/wallet"
)

// Ledger is the public interface of the module. Aggregates (reports, Phase 2) and PauseRules
// (Phase 3) join it with their phases; for now ledger's job for other modules is to answer
// "is this account / category still used?", exposed through the two checkers below.
type Ledger interface {
	// AccountReferences answers whether live transactions use an account (wallet's callback).
	AccountReferences() wallet.ReferenceChecker
	// CategoryReferences answers whether live transactions use a category (category's callback).
	CategoryReferences() category.ReferenceChecker
}
