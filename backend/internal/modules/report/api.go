// Package report composes the monthly report from the data of other modules. It owns no
// tables (docs/ARCHITECTURE.md §3.3).
package report

import (
	"context"

	"github.com/google/uuid"
)

// Timezones tells the IANA timezone of a user. The composition root implements it with
// identity's settings, because report may not import identity (docs/ARCHITECTURE.md §3.2).
type Timezones interface {
	Timezone(ctx context.Context, userID uuid.UUID) (string, error)
}
