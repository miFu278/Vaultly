package middleware_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/infras/crypto"
	"vaultly-be/internal/presentation/http/middleware"
)

// stubDevices answers device lookups from a fixed map.
type stubDevices struct {
	devices map[uuid.UUID]entity.Device
}

func (s stubDevices) Create(ctx context.Context, d *entity.Device) error { return nil }

func (s stubDevices) GetByID(ctx context.Context, id uuid.UUID) (*entity.Device, error) {
	d, ok := s.devices[id]
	if !ok {
		return nil, domain.ErrDeviceNotFound
	}
	return &d, nil
}

func (s stubDevices) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Device, error) {
	return nil, nil
}

func (s stubDevices) Revoke(ctx context.Context, userID, deviceID uuid.UUID) error { return nil }

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
	r.Use(middleware.AuthMiddleware(tokenSvc, stubDevices{devices: map[uuid.UUID]entity.Device{
		devID: {ID: devID, UserID: userID, PublicKey: "pk", Name: "Phone"},
	}}))
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

// Revoking a device used to only stamp revoked_at: the device kept working until
// its JWT expired. The token must stop being accepted immediately.
func TestAuthMiddleware_RejectsRevokedDevice(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tokenSvc := crypto.NewJWTTokenService("test_secret_key_12345", 1)
	userID, devID := uuid.New(), uuid.New()
	token, err := tokenSvc.Generate(service.TokenClaims{UserID: userID, Email: "test@example.com", DeviceID: &devID})
	if err != nil {
		t.Fatalf("Generate token failed: %v", err)
	}

	caseInsensitiveRevoked := time.Now()
	r := gin.New()
	r.Use(middleware.AuthMiddleware(tokenSvc, stubDevices{devices: map[uuid.UUID]entity.Device{
		devID: {ID: devID, UserID: userID, PublicKey: "pk", Name: "Phone", RevokedAt: &caseInsensitiveRevoked},
	}}))
	r.GET("/test-auth", func(c *gin.Context) { c.JSON(http.StatusOK, gin.H{"status": "ok"}) })

	req := httptest.NewRequest(http.MethodGet, "/test-auth", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Fatalf("Expected 401 for a revoked device, got %d. Body: %s", w.Code, w.Body.String())
	}
}
