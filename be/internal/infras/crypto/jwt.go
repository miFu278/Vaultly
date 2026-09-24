package crypto

import (
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/service"
)

type JWTClaims struct {
	UserID   uuid.UUID  `json:"user_id"`
	Email    string     `json:"email"`
	DeviceID *uuid.UUID `json:"device_id,omitempty"`
	jwt.RegisteredClaims
}

type JWTTokenService struct {
	secret          string
	expirationHours int
}

func NewJWTTokenService(secret string, expirationHours int) service.TokenService {
	return &JWTTokenService{
		secret:          secret,
		expirationHours: expirationHours,
	}
}

func (s *JWTTokenService) Generate(claims service.TokenClaims) (string, error) {
	jwtClaims := JWTClaims{
		UserID:   claims.UserID,
		Email:    claims.Email,
		DeviceID: claims.DeviceID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(s.expirationHours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "vaultly-backend",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwtClaims)
	return token.SignedString([]byte(s.secret))
}

func (s *JWTTokenService) Validate(tokenString string) (*service.TokenClaims, error) {
	if tokenString == "" {
		return nil, domain.ErrUnauthorized
	}

	// Handle Bearer prefix if present
	parts := strings.SplitN(tokenString, " ", 2)
	if len(parts) == 2 && strings.ToLower(parts[0]) == "bearer" {
		tokenString = parts[1]
	}

	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.secret), nil
	})

	if err != nil || !token.Valid {
		return nil, domain.ErrUnauthorized
	}

	claims, ok := token.Claims.(*JWTClaims)
	if !ok {
		return nil, domain.ErrUnauthorized
	}

	return &service.TokenClaims{
		UserID:   claims.UserID,
		Email:    claims.Email,
		DeviceID: claims.DeviceID,
	}, nil
}
