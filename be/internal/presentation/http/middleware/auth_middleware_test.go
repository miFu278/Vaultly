package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/infras/crypto"
	"vaultly-be/internal/presentation/http/middleware"
)

func TestGenerateAndValidateToken(t *testing.T) {
	gin.SetMode(gin.TestMode)

	secret := "test_secret_key_12345"
	tokenSvc := crypto.NewJWTTokenService(secret, 1)

	userID := uuid.New()
	email := "test@example.com"
	devID := uuid.New()

	token, err := tokenSvc.Generate(service.TokenClaims{
		UserID:   userID,
		Email:    email,
		DeviceID: &devID,
	})
	if err != nil {
		t.Fatalf("Generate token failed: %v", err)
	}

	r := gin.New()
	r.Use(middleware.AuthMiddleware(tokenSvc))
	r.GET("/test-auth", func(c *gin.Context) {
		ctxUserID, _ := c.Get("user_id")
		ctxEmail := c.GetString("email")
		ctxDevID, _ := c.Get("device_id")

		if ctxUserID != userID {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "user_id mismatch"})
			return
		}
		if ctxEmail != email {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "email mismatch"})
			return
		}
		if ctxDevID != devID {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "device_id mismatch"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// Test with valid token
	req := httptest.NewRequest(http.MethodGet, "/test-auth", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Expected status 200, got %d. Body: %s", w.Code, w.Body.String())
	}

	// Test without token
	reqNoAuth := httptest.NewRequest(http.MethodGet, "/test-auth", nil)
	wNoAuth := httptest.NewRecorder()
	r.ServeHTTP(wNoAuth, reqNoAuth)

	if wNoAuth.Code != http.StatusUnauthorized {
		t.Fatalf("Expected status 401 for missing token, got %d", wNoAuth.Code)
	}
}
