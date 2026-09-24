package entity

import (
	"time"

	"github.com/google/uuid"
)

type PairingStatus string

const (
	PairingStatusPending   PairingStatus = "pending"
	PairingStatusCompleted PairingStatus = "completed"
	PairingStatusExpired   PairingStatus = "expired"
)

// Pairing represents an ephemeral pairing session for a new device
type Pairing struct {
	ID              uuid.UUID     `json:"id"`
	PairingToken    string        `json:"pairing_token"`
	PublicKey       string        `json:"public_key"`
	DeviceName      string        `json:"device_name"`
	Status          PairingStatus `json:"status"` // pending, completed, expired
	UserID          *uuid.UUID    `json:"user_id,omitempty"`
	CreatedDeviceID *uuid.UUID    `json:"created_device_id,omitempty"`
	ExpiresAt       time.Time     `json:"expires_at"`
	CreatedAt       time.Time     `json:"created_at"`
}

// IsExpired checks if the pairing session has passed expiration time
func (p *Pairing) IsExpired() bool {
	return time.Now().After(p.ExpiresAt)
}
