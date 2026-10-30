package entity

import (
	"time"

	"github.com/google/uuid"
)

// User represents an account holder in the system.
//
// StorageQuotaBytes caps how much of the vault the account may fill. The
// dashboard compares it with FileUsage to draw the storage gauge.
type User struct {
	ID                uuid.UUID `json:"id"`
	Email             string    `json:"email"`
	PasswordHash      string    `json:"-"`
	PINHash           string    `json:"-"`
	StorageQuotaBytes int64     `json:"storage_quota_bytes"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// FileUsage is what an account currently occupies in the vault, split by media
// kind so the dashboard can draw the breakdown without a second query.
type FileUsage struct {
	TotalBytes int64 `json:"total_bytes"`
	PhotoBytes int64 `json:"photo_bytes"`
	VideoBytes int64 `json:"video_bytes"`
	FileCount  int64 `json:"file_count"`
}
