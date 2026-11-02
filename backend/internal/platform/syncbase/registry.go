package syncbase

// Registry collects the sync handlers of all modules. The sync module implements it;
// each module registers its handlers through RegisterSyncHandlers.
type Registry interface {
	Register(h Handler)
}
