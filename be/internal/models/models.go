package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents an account holder
type User struct {
	ID           uuid.UUID `json:"id"`
	Email        string    `json:"email"`
	PasswordHash string    `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// Device represents an authorized user device holding an X25519 keypair
type Device struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	PublicKey string     `json:"public_key"`
	Name      string     `json:"name"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

// File represents file metadata (ciphertext stored on R2)
type File struct {
	ID          uuid.UUID `json:"id"`
	UserID      uuid.UUID `json:"user_id"`
	R2ObjectKey string    `json:"r2_object_key"`
	Size        int64     `json:"size"`
	ContentType string    `json:"content_type"`
	Nonce       string    `json:"nonce"`
	Status      string    `json:"status"` // pending, ready, deleted
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// FileKey stores the wrapped File Key per authorized device
type FileKey struct {
	FileID     uuid.UUID `json:"file_id"`
	DeviceID   uuid.UUID `json:"device_id"`
	WrappedKey string    `json:"wrapped_key"`
	CreatedAt  time.Time `json:"created_at"`
}

// Pairing represents an ephemeral pairing session for a new device
type Pairing struct {
	ID              uuid.UUID  `json:"id"`
	PairingToken    string     `json:"pairing_token"`
	PublicKey       string     `json:"public_key"`
	DeviceName      string     `json:"device_name"`
	Status          string     `json:"status"` // pending, completed, expired
	UserID          *uuid.UUID `json:"user_id,omitempty"`
	CreatedDeviceID *uuid.UUID `json:"created_device_id,omitempty"`
	ExpiresAt       time.Time  `json:"expires_at"`
	CreatedAt       time.Time  `json:"created_at"`
}

// DTOs

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type AuthResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

type RegisterDeviceRequest struct {
	Name      string `json:"name" binding:"required"`
	PublicKey string `json:"public_key" binding:"required"`
}

type InitUploadRequest struct {
	Size        int64  `json:"size" binding:"required,gt=0"`
	ContentType string `json:"content_type" binding:"required"`
	Nonce       string `json:"nonce" binding:"required"`
}

type InitUploadResponse struct {
	FileID       uuid.UUID `json:"file_id"`
	PresignedURL string    `json:"presigned_url"`
	R2ObjectKey  string    `json:"r2_object_key"`
}

type DeviceWrappedKey struct {
	DeviceID   uuid.UUID `json:"device_id" binding:"required"`
	WrappedKey string    `json:"wrapped_key" binding:"required"`
}

type CompleteUploadRequest struct {
	WrappedKeys []DeviceWrappedKey `json:"wrapped_keys" binding:"required,dive"`
}

type DownloadResponse struct {
	PresignedURL string `json:"presigned_url"`
	WrappedKey   string `json:"wrapped_key"`
	Nonce        string `json:"nonce"`
	ContentType  string `json:"content_type"`
	Size         int64  `json:"size"`
}

type PairingStartRequest struct {
	PublicKey  string `json:"public_key" binding:"required"`
	DeviceName string `json:"device_name" binding:"required"`
}

type PairingStartResponse struct {
	PairingToken string    `json:"pairing_token"`
	ExpiresAt    time.Time `json:"expires_at"`
}

type PairingCompleteRequest struct {
	PairingToken string             `json:"pairing_token" binding:"required"`
	WrappedKeys  []DeviceWrappedKey `json:"wrapped_keys" binding:"required,dive"`
}
