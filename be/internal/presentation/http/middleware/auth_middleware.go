package middleware

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/repository"
	"vaultly-be/internal/domain/service"
)

// ResolveClaims validates a bearer token and, when the token names a device,
// confirms that device is still authorized for that user. Without the second
// check a revoked device keeps full access until its JWT expires.
func ResolveClaims(ctx context.Context, tokenSvc service.TokenService, devices repository.DeviceRepository, authHeader string) (*service.TokenClaims, error) {
	claims, err := tokenSvc.Validate(authHeader)
	if err != nil {
		return nil, err
	}
	if claims.DeviceID == nil {
		return claims, nil
	}
	device, err := devices.GetByID(ctx, *claims.DeviceID)
	if err != nil || device == nil || device.UserID != claims.UserID || !device.IsActive() {
		return nil, domain.ErrDeviceRevoked
	}
	return claims, nil
}

func AuthMiddleware(tokenSvc service.TokenService, devices repository.DeviceRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			if qToken := c.Query("token"); qToken != "" {
				authHeader = "Bearer " + qToken
			}
		}
		claims, err := ResolveClaims(c.Request.Context(), tokenSvc, devices, authHeader)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized: " + err.Error()})
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("email", claims.Email)
		if claims.DeviceID != nil {
			c.Set("device_id", *claims.DeviceID)
		} else if devHeader := c.GetHeader("X-Device-ID"); devHeader != "" {
			if parsedDevID, err := uuid.Parse(devHeader); err == nil {
				c.Set("device_id", parsedDevID)
			}
		}

		c.Next()
	}
}
