package database

import (
	"context"

	"gorm.io/gorm"
)

type txKey struct{}

// TxManager runs functions inside database transactions. The transaction travels in the
// context, so every repository that obtains its handle through DB(ctx) joins it.
type TxManager struct {
	db *gorm.DB
}

// NewTxManager wraps a GORM handle.
func NewTxManager(db *gorm.DB) *TxManager {
	return &TxManager{db: db}
}

// WithTx runs fn in a transaction. When ctx already carries a transaction, fn joins it
// (no nested transaction); an error from fn rolls back the outermost one.
func (m *TxManager) WithTx(ctx context.Context, fn func(ctx context.Context) error) error {
	if _, ok := ctx.Value(txKey{}).(*gorm.DB); ok {
		return fn(ctx)
	}
	return m.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		return fn(context.WithValue(ctx, txKey{}, tx))
	})
}

// DB returns the transaction stored in ctx, or the plain connection when there is none.
func (m *TxManager) DB(ctx context.Context) *gorm.DB {
	if tx, ok := ctx.Value(txKey{}).(*gorm.DB); ok {
		return tx.WithContext(ctx)
	}
	return m.db.WithContext(ctx)
}
