package pairing

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"vaultly-be/internal/config"
	"vaultly-be/internal/database"
	"vaultly-be/internal/middleware"
	"vaultly-be/internal/models"
)

type PairingService struct {
	db  *database.DB
	cfg *config.Config
}

func NewPairingService(db *database.DB, cfg *config.Config) *PairingService {
	return &PairingService{db: db, cfg: cfg}
}

// StartPairing initiates a new pairing session for Device B
func (s *PairingService) StartPairing(ctx context.Context, publicKey, deviceName string) (*models.PairingStartResponse, error) {
	// Generate random 32-byte hex token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return nil, err
	}
	token := hex.EncodeToString(tokenBytes)
	expiresAt := time.Now().Add(10 * time.Minute)

	query := `
		INSERT INTO pairings (pairing_token, public_key, device_name, status, expires_at, created_at)
		VALUES ($1, $2, $3, 'pending', $4, NOW())
	`
	_, err := s.db.Pool.Exec(ctx, query, token, publicKey, deviceName, expiresAt)
	if err != nil {
		return nil, err
	}

	return &models.PairingStartResponse{
		PairingToken: token,
		ExpiresAt:    expiresAt,
	}, nil
}

// GetPairingStatus checks the status of a pairing token (polled by Device B)
func (s *PairingService) GetPairingStatus(ctx context.Context, token string) (gin.H, error) {
	var pairing models.Pairing
	var email string
	query := `
		SELECT p.id, p.pairing_token, p.public_key, p.device_name, p.status, p.user_id, p.created_device_id, p.expires_at, p.created_at, COALESCE(u.email, '')
		FROM pairings p
		LEFT JOIN users u ON p.user_id = u.id
		WHERE p.pairing_token = $1
	`
	err := s.db.Pool.QueryRow(ctx, query, token).Scan(
		&pairing.ID, &pairing.PairingToken, &pairing.PublicKey, &pairing.DeviceName,
		&pairing.Status, &pairing.UserID, &pairing.CreatedDeviceID, &pairing.ExpiresAt, &pairing.CreatedAt, &email,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("pairing session not found")
		}
		return nil, err
	}

	if time.Now().After(pairing.ExpiresAt) && pairing.Status == "pending" {
		pairing.Status = "expired"
	}

	result := gin.H{
		"status":      pairing.Status,
		"device_name": pairing.DeviceName,
		"expires_at":  pairing.ExpiresAt,
	}

	if pairing.Status == "completed" && pairing.UserID != nil && pairing.CreatedDeviceID != nil {
		jwtToken, _ := middleware.GenerateToken(*pairing.UserID, email, pairing.CreatedDeviceID, s.cfg.JWTSecret, s.cfg.JWTExpirationHours)
		result["jwt_token"] = jwtToken
		result["device_id"] = pairing.CreatedDeviceID
		result["user_id"] = pairing.UserID
	}

	return result, nil
}

// CompletePairing is called by Device A (authenticated user) to approve Device B
func (s *PairingService) CompletePairing(ctx context.Context, userID uuid.UUID, req models.PairingCompleteRequest) error {
	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Fetch pairing session
	var pairing models.Pairing
	query := `
		SELECT id, pairing_token, public_key, device_name, status, expires_at
		FROM pairings
		WHERE pairing_token = $1 FOR UPDATE
	`
	err = tx.QueryRow(ctx, query, req.PairingToken).Scan(
		&pairing.ID, &pairing.PairingToken, &pairing.PublicKey, &pairing.DeviceName, &pairing.Status, &pairing.ExpiresAt,
	)
	if err != nil {
		return errors.New("pairing session not found")
	}

	if pairing.Status != "pending" || time.Now().After(pairing.ExpiresAt) {
		return errors.New("pairing session is expired or already processed")
	}

	// Create new device for Device B
	var newDeviceID uuid.UUID
	insertDevQuery := `
		INSERT INTO devices (user_id, public_key, name, created_at)
		VALUES ($1, $2, $3, NOW())
		RETURNING id
	`
	err = tx.QueryRow(ctx, insertDevQuery, userID, pairing.PublicKey, pairing.DeviceName).Scan(&newDeviceID)
	if err != nil {
		return err
	}

	// Insert wrapped keys for existing files for Device B
	keyInsertQuery := `
		INSERT INTO file_keys (file_id, device_id, wrapped_key, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (file_id, device_id) DO UPDATE SET wrapped_key = EXCLUDED.wrapped_key
	`
	for _, wk := range req.WrappedKeys {
		_, err = tx.Exec(ctx, keyInsertQuery, wk.DeviceID, newDeviceID, wk.WrappedKey)
		if err != nil {
			return err
		}
	}

	// Mark pairing as completed
	updatePairingQuery := `
		UPDATE pairings
		SET status = 'completed', user_id = $1, created_device_id = $2
		WHERE id = $3
	`
	_, err = tx.Exec(ctx, updatePairingQuery, userID, newDeviceID, pairing.ID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

type PairingHandler struct {
	service *PairingService
}

func NewPairingHandler(service *PairingService) *PairingHandler {
	return &PairingHandler{service: service}
}

func (h *PairingHandler) Start(c *gin.Context) {
	var req models.PairingStartRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	resp, err := h.service.StartPairing(c.Request.Context(), req.PublicKey, req.DeviceName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *PairingHandler) Status(c *gin.Context) {
	token := c.Param("token")
	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Pairing token is required"})
		return
	}

	resp, err := h.service.GetPairingStatus(c.Request.Context(), token)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *PairingHandler) Complete(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	var req models.PairingCompleteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.CompletePairing(c.Request.Context(), userID, req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Pairing completed and device authorized"})
}
