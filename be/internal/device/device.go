package device

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/database"
	"vaultly-be/internal/models"
)

type DeviceService struct {
	db *database.DB
}

func NewDeviceService(db *database.DB) *DeviceService {
	return &DeviceService{db: db}
}

// RegisterDevice registers a new public key for a user device
func (s *DeviceService) RegisterDevice(ctx context.Context, userID uuid.UUID, name, publicKey string) (*models.Device, error) {
	device := models.Device{
		UserID:    userID,
		PublicKey: publicKey,
		Name:      name,
		CreatedAt: time.Now(),
	}

	query := `
		INSERT INTO devices (user_id, public_key, name, created_at)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, public_key, name, created_at, revoked_at
	`
	err := s.db.Pool.QueryRow(ctx, query, device.UserID, device.PublicKey, device.Name, device.CreatedAt).
		Scan(&device.ID, &device.UserID, &device.PublicKey, &device.Name, &device.CreatedAt, &device.RevokedAt)
	if err != nil {
		return nil, err
	}

	return &device, nil
}

// ListDevices returns all active (non-revoked) devices for a user
func (s *DeviceService) ListDevices(ctx context.Context, userID uuid.UUID) ([]models.Device, error) {
	query := `
		SELECT id, user_id, public_key, name, created_at, revoked_at
		FROM devices
		WHERE user_id = $1 AND revoked_at IS NULL
		ORDER BY created_at ASC
	`
	rows, err := s.db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []models.Device
	for rows.Next() {
		var dev models.Device
		if err := rows.Scan(&dev.ID, &dev.UserID, &dev.PublicKey, &dev.Name, &dev.CreatedAt, &dev.RevokedAt); err != nil {
			return nil, err
		}
		devices = append(devices, dev)
	}

	if devices == nil {
		devices = []models.Device{}
	}

	return devices, nil
}

// RevokeDevice revokes a device by setting revoked_at timestamp
func (s *DeviceService) RevokeDevice(ctx context.Context, userID, deviceID uuid.UUID) error {
	query := `
		UPDATE devices
		SET revoked_at = NOW()
		WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL
	`
	tag, err := s.db.Pool.Exec(ctx, query, deviceID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("device not found or already revoked")
	}
	return nil
}

type DeviceHandler struct {
	service *DeviceService
}

func NewDeviceHandler(service *DeviceService) *DeviceHandler {
	return &DeviceHandler{service: service}
}

func (h *DeviceHandler) Register(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	var req models.RegisterDeviceRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	dev, err := h.service.RegisterDevice(c.Request.Context(), userID, req.Name, req.PublicKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, dev)
}

func (h *DeviceHandler) List(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	devices, err := h.service.ListDevices(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, devices)
}

func (h *DeviceHandler) Revoke(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	deviceIDStr := c.Param("id")
	deviceID, err := uuid.Parse(deviceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid device id"})
		return
	}

	if err := h.service.RevokeDevice(c.Request.Context(), userID, deviceID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Device revoked successfully"})
}
