// Package service holds the sync orchestration: registry, push, and pull.
package service

import (
	"fmt"

	"moneytracker/internal/platform/syncbase"
)

// Registry collects the entity handlers of all modules. It is filled while the application is
// assembled and only read afterwards, so it needs no locking.
type Registry struct {
	handlers map[string]syncbase.Handler
	order    []syncbase.Handler
}

// NewRegistry builds an empty registry.
func NewRegistry() *Registry {
	return &Registry{handlers: map[string]syncbase.Handler{}}
}

// Register adds a handler. Registering the same entity twice is a programming error.
func (r *Registry) Register(h syncbase.Handler) {
	entity := h.Entity()
	if _, exists := r.handlers[entity]; exists {
		panic(fmt.Sprintf("sync: entity %q registered twice", entity))
	}
	r.handlers[entity] = h
	r.order = append(r.order, h)
}

// Get returns the handler of an entity.
func (r *Registry) Get(entity string) (syncbase.Handler, bool) {
	h, ok := r.handlers[entity]
	return h, ok
}

// All returns the handlers in registration order.
func (r *Registry) All() []syncbase.Handler {
	return r.order
}
