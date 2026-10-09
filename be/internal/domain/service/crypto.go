package service

import (
	"io"

	"github.com/google/uuid"
)

// DecryptedStream is a seekable plaintext view of one encrypted object. It
// serves HTTP Range requests without buffering the whole object in memory.
type DecryptedStream interface {
	io.ReadSeeker
	io.Closer

	// Size is the total plaintext length, known before the first read.
	Size() int64
}

// EncryptionService defines the contract for encrypting and decrypting files/images
// using Libsodium-compatible primitives:
// 1. Image streaming encryption: crypto_secretstream_xchacha20poly1305 (chunked 64KB)
// 2. Direct AEAD: XChaCha20-Poly1305 (192-bit / 24-byte nonce)
// 3. Key wrapping: crypto_box_seal (X25519 sealed box)
type EncryptionService interface {
	// GenerateFileKey creates a cryptographically secure 256-bit (32 bytes) symmetric File Key
	GenerateFileKey() ([]byte, error)

	// GenerateNonce creates a secure 192-bit (24 bytes) random nonce for XChaCha20
	GenerateNonce() ([]byte, error)

	// EncryptStream encrypts an arbitrary stream (io.Reader to io.Writer) in chunks
	// using crypto_secretstream_xchacha20poly1305 with anti-truncation protection.
	// It returns the 24-byte stream header, which is the nonce side of the payload.
	EncryptStream(r io.Reader, w io.Writer, key []byte) (header []byte, err error)

	// EncryptSegmentedStream encrypts a stream as independent segments so any byte
	// range can later be decrypted on its own (O(1) seek). w must be seekable so
	// the plaintext size can be written into the object header once it is known.
	// It returns the plaintext size and the first segment's stream header.
	EncryptSegmentedStream(r io.Reader, w io.WriteSeeker, key []byte) (plainSize int64, header []byte, err error)

	// DecryptStream decrypts an encrypted stream (io.Reader to io.Writer) in chunks
	// using crypto_secretstream_xchacha20poly1305 and validates completeness.
	DecryptStream(r io.Reader, w io.Writer, key []byte) error

	// OpenDecryptStream detects the stored layout and returns a plaintext
	// io.ReadSeeker for HTTP range serving. src must be positioned at byte 0 with
	// cipherLen its exact size; src is reused for the first segment and fetch
	// returns a stream of length bytes starting at offset.
	OpenDecryptStream(key []byte, cipherLen int64, src io.ReadCloser, fetch func(offset, length int64) (io.ReadCloser, error)) (DecryptedStream, error)

	// EncryptBytes encrypts plaintext in-memory using crypto_secretstream_xchacha20poly1305
	EncryptBytes(plaintext, key []byte) (ciphertext []byte, header []byte, err error)

	// DecryptBytes decrypts ciphertext in-memory using crypto_secretstream_xchacha20poly1305
	DecryptBytes(ciphertext, key []byte) (plaintext []byte, err error)

	// WrapKeyForDevice wraps a 32-byte File Key for an authorized device using crypto_box_seal (X25519)
	WrapKeyForDevice(fileKey []byte, recipientPublicKey string) (wrappedKeyHex string, err error)

	// UnwrapKeyForDevice unwraps a wrapped File Key using crypto_box_seal_open (X25519 recipient keypair)
	UnwrapKeyForDevice(wrappedKeyHex string, recipientPublicKey, recipientPrivateKey string) ([]byte, error)

	// ValidateImage verifies magic bytes for supported image formats (JPEG, PNG, WebP, GIF)
	ValidateImage(data []byte) (mimeType string, err error)
}

// PasswordHasher defines hashing and verifying user passwords
type PasswordHasher interface {
	Hash(password string) (string, error)
	Compare(hashedPassword, password string) error
}

// TokenClaims represents JWT token payload
type TokenClaims struct {
	UserID   uuid.UUID
	Email    string
	DeviceID *uuid.UUID
}

// TokenService defines token generation and validation contract
type TokenService interface {
	Generate(claims TokenClaims) (string, error)
	Validate(tokenString string) (*TokenClaims, error)
}

// ReadSeekCloser is a seekable, closable byte stream, as served by object
// storage and multipart uploads.
type ReadSeekCloser interface {
	io.ReadSeeker
	io.Closer
}

// Thumbnailer turns a still image into a small JPEG preview that galleries can
// load without touching the full-resolution object.
type Thumbnailer interface {
	// Generate returns the encoded JPEG, or nil when r holds something that is not
	// a still image (video) or is too large to decode safely.
	Generate(r io.ReadSeeker) ([]byte, error)
}
