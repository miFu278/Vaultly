package domain

import "errors"

var (
	// User errors
	ErrUserNotFound       = errors.New("user not found")
	ErrEmailAlreadyExists = errors.New("email already registered")
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrUnauthorized       = errors.New("unauthorized")

	// Device errors
	ErrDeviceNotFound     = errors.New("device not found")
	ErrDeviceRevoked      = errors.New("device already revoked")
	ErrDeviceUnauthorized = errors.New("device not authorized to decrypt this file")

	// File errors
	ErrFileNotFound   = errors.New("file not found")
	ErrFileNotPending = errors.New("file is not in pending status")
	ErrInvalidImage   = errors.New("file is not a valid or supported media format (JPEG, PNG, WebP, GIF, MP4, WebM, MOV allowed)")
	ErrFileTooLarge   = errors.New("file exceeds maximum allowed size")

	// Pairing errors
	ErrPairingNotFound         = errors.New("pairing session not found")
	ErrPairingExpired          = errors.New("pairing session has expired")
	ErrPairingAlreadyProcessed = errors.New("pairing session is already completed or invalid")

	// Crypto / Encryption errors
	ErrEncryptionFailed   = errors.New("failed to encrypt file payload")
	ErrDecryptionFailed   = errors.New("failed to decrypt file ciphertext")
	ErrInvalidKeyLength   = errors.New("invalid key length (must be 32 bytes)")
	ErrInvalidNonceLength = errors.New("invalid nonce length (must be 24 bytes for XChaCha20)")
	ErrInvalidPublicKey   = errors.New("invalid recipient public key (must be 32-byte X25519 key)")
	ErrInvalidPrivateKey  = errors.New("invalid recipient private key (must be 32-byte X25519 key)")
	ErrStreamTruncated    = errors.New("encrypted stream truncated or incomplete (anti-truncation validation failed)")
)
