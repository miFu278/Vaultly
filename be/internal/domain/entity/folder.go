package entity

import (
	"time"

	"github.com/google/uuid"
)

// Folder represents a user-created folder (Knox Secure Folder inspired)
type Folder struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}
