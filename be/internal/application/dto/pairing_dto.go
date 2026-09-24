package dto

import (
	"time"

	"github.com/google/uuid"
)

type PairingStartRequest struct {
	PublicKey  string `json:"public_key" binding:"required" example:"device-b-public-key"`
	DeviceName string `json:"device_name" binding:"required" example:"MacBook Pro"`
}

type PairingStartResponse struct {
	PairingToken string    `json:"pairing_token"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type PairingStatusResponse struct {
	Status     string     `json:"status"` // pending, completed, expired
	DeviceName string     `json:"device_name"`
	ExpiresAt  time.Time  `json:"expires_at"`
	JWTToken   *string    `json:"jwt_token,omitempty"`
	DeviceID   *uuid.UUID `json:"device_id,omitempty"`
	UserID     *uuid.UUID `json:"user_id,omitempty"`
}

type PairingCompleteRequest struct {
	PairingToken string             `json:"pairing_token" binding:"required"`
	WrappedKeys  []DeviceWrappedKey `json:"wrapped_keys" binding:"required,dive"`
}
