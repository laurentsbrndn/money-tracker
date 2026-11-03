// Package sync implements push and pull for the offline-first apps (docs/SYNC_PROTOCOL.md).
// The entity handlers belong to the modules that own the tables; they register themselves in
// the Registry that this package provides.
package sync

import "moneytracker/internal/modules/sync/internal/service"

// Registry collects the sync handlers of all modules.
type Registry = service.Registry

// NewRegistry builds an empty registry. The composition root creates it, lets every module
// register its handlers, and passes it to New.
func NewRegistry() *Registry {
	return service.NewRegistry()
}
