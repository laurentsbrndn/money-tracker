package syncbase

import (
	"encoding/json"
	"errors"
	"fmt"

	"moneytracker/internal/platform/httpx"
)

// Decode parses the data of an upsert into T and validates it with T's `validate` tags.
//
// Fields that are required and non-null are declared as pointers with `validate:"required"`,
// so a missing key is rejected with validation. Nullable fields are plain pointers: a missing
// key is treated the same as null (docs/SYNC_PROTOCOL.md §8.1). Unknown keys (user_id,
// server_version, ...) are ignored. The error is always a *RejectError.
func Decode[T any](data json.RawMessage) (T, *RejectError) {
	var dst T
	if len(data) == 0 || string(data) == "null" {
		return dst, Invalid("data wajib diisi untuk op upsert")
	}
	if err := json.Unmarshal(data, &dst); err != nil {
		var typeErr *json.UnmarshalTypeError
		if errors.As(err, &typeErr) && typeErr.Field != "" {
			return dst, InvalidField(typeErr.Field, "tipe data tidak sesuai")
		}
		return dst, Invalid(fmt.Sprintf("data bukan JSON yang valid: %v", err))
	}
	if err := httpx.Validate(dst); err != nil {
		if appErr, ok := httpx.As(err); ok {
			return dst, Invalid(appErr.Detail, appErr.Fields...)
		}
		return dst, Invalid("data tidak valid")
	}
	return dst, nil
}
