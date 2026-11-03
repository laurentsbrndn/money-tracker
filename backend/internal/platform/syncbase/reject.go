package syncbase

import "moneytracker/internal/platform/httpx"

// Invalid rejects a change that breaks a validation rule. It is not retryable.
func Invalid(message string, fields ...httpx.FieldError) *RejectError {
	return &RejectError{Code: RejectValidation, Message: message, Fields: fields}
}

// InvalidField rejects a change because one field is invalid.
func InvalidField(field, message string) *RejectError {
	return Invalid(message, httpx.FieldError{Field: field, Message: message})
}

// ReferenceMissing rejects a change whose referenced row does not exist (yet) for the user.
// It is retryable: the parent may be pushed in a later batch.
func ReferenceMissing(message string) *RejectError {
	return &RejectError{Code: RejectReferenceMissing, Message: message, Retryable: true}
}

// PlanLimit rejects a change that exceeds the free plan limits. It is not retryable.
func PlanLimit(message string) *RejectError {
	return &RejectError{Code: RejectPlanLimit, Message: message}
}

// Forbidden rejects a change to a row owned by another user.
func Forbidden(message string) *RejectError {
	return &RejectError{Code: RejectForbidden, Message: message}
}
