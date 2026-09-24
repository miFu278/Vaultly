package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/domain/service"
)

func AuthMiddleware(tokenSvc service.TokenService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		claims, err := tokenSvc.Validate(authHeader)
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
