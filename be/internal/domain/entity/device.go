package entity

import (
	"time"

	"github.com/google/uuid"
)

// Device represents an authorized user device holding an X25519 keypair
type Device struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	PublicKey string     `json:"public_key"`
	Name      string     `json:"name"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

// IsActive returns true if the device is not revoked
func (d *Device) IsActive() bool {
	return d.RevokedAt == nil
}
