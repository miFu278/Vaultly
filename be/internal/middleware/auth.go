package middleware

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type JWTClaims struct {
	UserID   uuid.UUID  `json:"user_id"`
	Email    string     `json:"email"`
	DeviceID *uuid.UUID `json:"device_id,omitempty"`
	jwt.RegisteredClaims
}

// GenerateToken generates a signed JWT token
func GenerateToken(userID uuid.UUID, email string, deviceID *uuid.UUID, secret string, expirationHours int) (string, error) {
	claims := JWTClaims{
		UserID:   userID,
		Email:    email,
		DeviceID: deviceID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(expirationHours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "vaultly-backend",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// ValidateToken validates a raw Authorization header string and returns the claims
func ValidateToken(authHeader string, secret string) (*JWTClaims, error) {
	if authHeader == "" {
		return nil, fmt.Errorf("Authorization header is required")
	}

	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
		return nil, fmt.Errorf("Invalid authorization header format. Expected Bearer <token>")
	}

	tokenString := parts[1]
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(secret), nil
	})

	if err != nil || !token.Valid {
		return nil, fmt.Errorf("Invalid or expired token")
	}

	claims, ok := token.Claims.(*JWTClaims)
	if !ok {
		return nil, fmt.Errorf("Unable to parse token claims")
	}

	return claims, nil
}

// AuthMiddleware validates the JWT token in Authorization: Bearer <token>
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		claims, err := ValidateToken(c.GetHeader("Authorization"), secret)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
			return
		}

		// Store user and device in context
		c.Set("user_id", claims.UserID)
		c.Set("email", claims.Email)
		if claims.DeviceID != nil {
			c.Set("device_id", *claims.DeviceID)
		} else {
			// Check if client passed X-Device-ID header
			if devHeader := c.GetHeader("X-Device-ID"); devHeader != "" {
				if parsedDevID, err := uuid.Parse(devHeader); err == nil {
					c.Set("device_id", parsedDevID)
				}
			}
		}

		c.Next()
	}
}

// CORSMiddleware handles Cross-Origin Resource Sharing
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With, X-Device-ID")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE, PATCH")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
