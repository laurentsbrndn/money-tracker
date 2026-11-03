// Package dto holds the HTTP request and response shapes of the identity module
// (contracts/openapi.yaml).
package dto

// RegisterRequest is the body of POST /v1/auth/register.
type RegisterRequest struct {
	Name     string `json:"name" validate:"required,max=100"`
	Email    string `json:"email" validate:"required,email,max=254"`
	Password string `json:"password" validate:"required,min=8,max=72"`
	Timezone string `json:"timezone" validate:"required"`
}

// LoginRequest is the body of POST /v1/auth/login.
type LoginRequest struct {
	Email    string `json:"email" validate:"required,email,max=254"`
	Password string `json:"password" validate:"required,max=72"`
}

// VerifyEmailRequest is the body of POST /v1/auth/email/verify.
type VerifyEmailRequest struct {
	Code string `json:"code" validate:"required,len=6,numeric"`
}

// ForgotPasswordRequest is the body of POST /v1/auth/password/forgot.
type ForgotPasswordRequest struct {
	Email string `json:"email" validate:"required,email,max=254"`
}

// ResetPasswordRequest is the body of POST /v1/auth/password/reset.
type ResetPasswordRequest struct {
	Email       string `json:"email" validate:"required,email,max=254"`
	Code        string `json:"code" validate:"required,len=6,numeric"`
	NewPassword string `json:"new_password" validate:"required,min=8,max=72"`
}

// ChangePasswordRequest is the body of POST /v1/auth/password/change.
type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required,max=72"`
	NewPassword     string `json:"new_password" validate:"required,min=8,max=72"`
}

// UpdateMeRequest is the body of PATCH /v1/me.
type UpdateMeRequest struct {
	Name string `json:"name" validate:"required,max=100"`
}

// DeleteMeRequest is the body of DELETE /v1/me.
type DeleteMeRequest struct {
	Confirmation string `json:"confirmation" validate:"required"`
}

// RefreshRequest is the body of POST /v1/auth/refresh and POST /v1/auth/logout.
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required,max=256"`
}

// AppleLoginRequest is the body of POST /v1/auth/oauth/apple.
type AppleLoginRequest struct {
	IdentityToken string `json:"identity_token" validate:"required"`
	Name          string `json:"name" validate:"max=100"`
	Timezone      string `json:"timezone" validate:"required"`
}

// GoogleLoginRequest is the body of POST /v1/auth/oauth/google.
type GoogleLoginRequest struct {
	IDToken  string `json:"id_token" validate:"required"`
	Timezone string `json:"timezone" validate:"required"`
}
