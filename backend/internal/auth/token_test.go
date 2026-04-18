package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestTokenManager_SignParseByType(t *testing.T) {
	secret := []byte("test-secret")
	accessTM := TokenManager{
		Secret:    secret,
		Issuer:    "lms-test",
		TTL:       time.Hour,
		TokenType: "access",
	}
	refreshTM := TokenManager{
		Secret:    secret,
		Issuer:    "lms-test",
		TTL:       24 * time.Hour,
		TokenType: "refresh",
	}

	uid := uuid.New()
	access, err := accessTM.Sign(uid, "student")
	if err != nil {
		t.Fatalf("sign access: %v", err)
	}
	refresh, err := refreshTM.Sign(uid, "student")
	if err != nil {
		t.Fatalf("sign refresh: %v", err)
	}

	if _, err := accessTM.Parse(access); err != nil {
		t.Fatalf("parse access: %v", err)
	}
	if _, err := refreshTM.Parse(refresh); err != nil {
		t.Fatalf("parse refresh: %v", err)
	}

	if _, err := accessTM.Parse(refresh); err == nil {
		t.Fatalf("expected access parser to reject refresh token")
	}
	if _, err := refreshTM.Parse(access); err == nil {
		t.Fatalf("expected refresh parser to reject access token")
	}
}
