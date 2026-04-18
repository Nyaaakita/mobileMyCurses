package auth

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type TokenManager struct {
	Secret    []byte
	Issuer    string
	TTL       time.Duration
	TokenType string
}

type Claims struct {
	UserID    string `json:"uid"`
	Role      string `json:"role"`
	TokenType string `json:"typ"`
	jwt.RegisteredClaims
}

func (tm TokenManager) Sign(userID uuid.UUID, role string) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID: userID.String(),
		Role:   role,
		TokenType: tm.TokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    tm.Issuer,
			Subject:   userID.String(),
			ExpiresAt: jwt.NewNumericDate(now.Add(tm.TTL)),
			IssuedAt:  jwt.NewNumericDate(now),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(tm.Secret)
}

func (tm TokenManager) Parse(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return tm.Secret, nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, jwt.ErrTokenInvalidClaims
	}
	if tm.TokenType != "" && claims.TokenType != tm.TokenType {
		return nil, jwt.ErrTokenInvalidClaims
	}
	return claims, nil
}
