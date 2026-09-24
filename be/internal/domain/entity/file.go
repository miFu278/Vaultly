package entity

import (
	"time"

	"github.com/google/uuid"
)

type FileStatus string

const (
	FileStatusPending FileStatus = "pending"
	FileStatusReady   FileStatus = "ready"
	FileStatusDeleted FileStatus = "deleted"
)

// File represents encrypted file metadata stored on R2/S3
type File struct {
	ID             uuid.UUID  `json:"id"`
	UserID         uuid.UUID  `json:"user_id"`
	FolderID       *uuid.UUID `json:"folder_id,omitempty"`
	R2ObjectKey    string     `json:"r2_object_key"`
	R2ThumbnailKey string     `json:"r2_thumbnail_key,omitempty"`
	Size           int64      `json:"size"`
	ContentType    string     `json:"content_type"`
	Nonce          string     `json:"nonce"`
	Status         FileStatus `json:"status"` // pending, ready, deleted
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

// FileKey stores the wrapped File Key per authorized device
type FileKey struct {
	FileID     uuid.UUID `json:"file_id"`
	DeviceID   uuid.UUID `json:"device_id"`
	WrappedKey string    `json:"wrapped_key"`
	CreatedAt  time.Time `json:"created_at"`
}
