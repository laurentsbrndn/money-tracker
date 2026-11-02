package auth

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"

	"github.com/google/uuid"
)

const otpDigits = 1_000_000

// OTP generates and hashes 6-digit verification codes.
type OTP struct {
	secret []byte
}

// NewOTP builds an OTP helper keyed with OTP_SECRET.
func NewOTP(secret string) *OTP {
	return &OTP{secret: []byte(secret)}
}

// Generate returns a uniformly random zero-padded 6-digit code.
func (o *OTP) Generate() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(otpDigits))
	if err != nil {
		return "", fmt.Errorf("generate otp: %w", err)
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// Hash returns the HMAC-SHA256 hex digest (64 characters) of the code bound to userID.
func (o *OTP) Hash(code string, userID uuid.UUID) string {
	mac := hmac.New(sha256.New, o.secret)
	mac.Write([]byte(userID.String()))
	mac.Write([]byte{':'})
	mac.Write([]byte(code))
	return hex.EncodeToString(mac.Sum(nil))
}

// Verify reports, in constant time, whether code matches the stored hash.
func (o *OTP) Verify(code string, userID uuid.UUID, storedHash string) bool {
	return hmac.Equal([]byte(o.Hash(code, userID)), []byte(storedHash))
}
