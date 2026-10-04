package crypto

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/openziti/secretstream"
	"golang.org/x/crypto/nacl/box"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/service"
)

const (
	// DefaultChunkSize is 64KB for chunked stream encryption
	DefaultChunkSize = 64 * 1024
)

type SodiumCryptoService struct {
	chunkSize int
}

func NewSodiumCryptoService() service.EncryptionService {
	return &SodiumCryptoService{
		chunkSize: DefaultChunkSize,
	}
}

// GenerateFileKey generates a random 32-byte (256-bit) File Key
func (s *SodiumCryptoService) GenerateFileKey() ([]byte, error) {
	key := make([]byte, 32)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, fmt.Errorf("failed to generate random File Key: %w", err)
	}
	return key, nil
}

// GenerateNonce generates a random 24-byte (192-bit) Nonce for XChaCha20
func (s *SodiumCryptoService) GenerateNonce() ([]byte, error) {
	nonce := make([]byte, 24)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("failed to generate random nonce: %w", err)
	}
	return nonce, nil
}

// EncryptStream encrypts an input stream in chunks using libsodium crypto_secretstream_xchacha20poly1305.
// Output format:
// [24 bytes Header] + for each chunk: [4 bytes length (uint32 big-endian)] [cipherChunk bytes]
func (s *SodiumCryptoService) EncryptStream(r io.Reader, w io.Writer, key []byte) error {
	if len(key) != 32 {
		return domain.ErrInvalidKeyLength
	}

	enc, header, err := secretstream.NewEncryptor(key)
	if err != nil {
		return fmt.Errorf("%w: failed to initialize secretstream encryptor: %v", domain.ErrEncryptionFailed, err)
	}

	// Write 24-byte secretstream header
	if _, err := w.Write(header); err != nil {
		return fmt.Errorf("failed to write stream header: %w", err)
	}

	buf := make([]byte, s.chunkSize)
	for {
		n, err := io.ReadFull(r, buf)
		if n == 0 && (err == io.EOF || err == io.ErrUnexpectedEOF) {
			// Empty input stream edge-case: push TagFinal with 0-byte payload
			cipherChunk, encErr := enc.Push(nil, secretstream.TagFinal)
			if encErr != nil {
				return encErr
			}
			return s.writeChunk(w, cipherChunk)
		}

		currentChunk := buf[:n]

		// Check if there is more data remaining after this chunk
		peek := make([]byte, 1)
		peekN, peekErr := r.Read(peek)

		tag := byte(secretstream.TagMessage)
		isLast := false
		if peekN == 0 && (peekErr == io.EOF || peekErr == io.ErrUnexpectedEOF) {
			isLast = true
			tag = byte(secretstream.TagFinal)
		}

		cipherChunk, encErr := enc.Push(currentChunk, tag)
		if encErr != nil {
			return fmt.Errorf("%w: %v", domain.ErrEncryptionFailed, encErr)
		}

		if err := s.writeChunk(w, cipherChunk); err != nil {
			return err
		}

		if isLast {
			break
		}

		// Re-construct stream: current byte read from peek must precede next chunk
		r = io.MultiReader(bytes.NewReader(peek[:peekN]), r)
	}

	return nil
}

func (s *SodiumCryptoService) writeChunk(w io.Writer, cipherChunk []byte) error {
	var lenBuf [4]byte
	binary.BigEndian.PutUint32(lenBuf[:], uint32(len(cipherChunk)))
	if _, err := w.Write(lenBuf[:]); err != nil {
		return err
	}
	if _, err := w.Write(cipherChunk); err != nil {
		return err
	}
	return nil
}

// DecryptStream decrypts an encrypted stream using libsodium crypto_secretstream_xchacha20poly1305.
func (s *SodiumCryptoService) DecryptStream(r io.Reader, w io.Writer, key []byte) error {
	if len(key) != 32 {
		return domain.ErrInvalidKeyLength
	}

	// Read 24-byte header
	header := make([]byte, secretstream.StreamHeaderBytes)
	if _, err := io.ReadFull(r, header); err != nil {
		return fmt.Errorf("failed to read secretstream header: %w", err)
	}

	dec, err := secretstream.NewDecryptor(key, header)
	if err != nil {
		return fmt.Errorf("%w: failed to initialize secretstream decryptor: %v", domain.ErrDecryptionFailed, err)
	}

	var lenBuf [4]byte
	gotFinalTag := false

	for {
		// Read 4-byte chunk length
		_, err := io.ReadFull(r, lenBuf[:])
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("unexpected EOF reading chunk length: %w", err)
		}

		chunkLen := binary.BigEndian.Uint32(lenBuf[:])
		chunkBuf := make([]byte, chunkLen)
		if _, err := io.ReadFull(r, chunkBuf); err != nil {
			return fmt.Errorf("unexpected EOF reading chunk payload: %w", err)
		}

		plainChunk, tag, decErr := dec.Pull(chunkBuf)
		if decErr != nil {
			return fmt.Errorf("%w: secretstream chunk verification failed: %v", domain.ErrDecryptionFailed, decErr)
		}

		if _, err := w.Write(plainChunk); err != nil {
			return fmt.Errorf("failed to write decrypted chunk: %w", err)
		}

		if tag == secretstream.TagFinal {
			gotFinalTag = true
			break
		}
	}

	// Verify that the stream was not truncated before the final tag
	if !gotFinalTag {
		return domain.ErrStreamTruncated
	}

	return nil
}

// EncryptBytes is an in-memory helper for EncryptStream
func (s *SodiumCryptoService) EncryptBytes(plaintext, key []byte) ([]byte, []byte, error) {
	var out bytes.Buffer
	if err := s.EncryptStream(bytes.NewReader(plaintext), &out, key); err != nil {
		return nil, nil, err
	}
	allBytes := out.Bytes()
	if len(allBytes) < secretstream.StreamHeaderBytes {
		return nil, nil, domain.ErrEncryptionFailed
	}
	header := allBytes[:secretstream.StreamHeaderBytes]
	return allBytes, header, nil
}

// DecryptBytes is an in-memory helper for DecryptStream
func (s *SodiumCryptoService) DecryptBytes(ciphertext, key []byte) ([]byte, error) {
	var out bytes.Buffer
	if err := s.DecryptStream(bytes.NewReader(ciphertext), &out, key); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

// WrapKeyForDevice wraps a File Key using libsodium's crypto_box_seal (X25519 sealed box)
func (s *SodiumCryptoService) WrapKeyForDevice(fileKey []byte, recipientPublicKey string) (string, error) {
	if len(fileKey) != 32 {
		return "", domain.ErrInvalidKeyLength
	}

	pubKeyBytes, err := parse32ByteKey(recipientPublicKey)
	if err != nil {
		return "", domain.ErrInvalidPublicKey
	}

	// crypto_box_seal via box.SealAnonymous
	sealedBox, err := box.SealAnonymous(nil, fileKey, pubKeyBytes, rand.Reader)
	if err != nil {
		return "", fmt.Errorf("crypto_box_seal failed: %w", err)
	}

	return hex.EncodeToString(sealedBox), nil
}

// UnwrapKeyForDevice unwraps a wrapped File Key using libsodium's crypto_box_seal_open
func (s *SodiumCryptoService) UnwrapKeyForDevice(wrappedKeyHex string, recipientPublicKey, recipientPrivateKey string) ([]byte, error) {
	sealedBox, err := hex.DecodeString(wrappedKeyHex)
	if err != nil {
		return nil, fmt.Errorf("invalid wrapped key hex: %w", err)
	}

	pubKey, err := parse32ByteKey(recipientPublicKey)
	if err != nil {
		return nil, domain.ErrInvalidPublicKey
	}

	privKey, err := parse32ByteKey(recipientPrivateKey)
	if err != nil {
		return nil, domain.ErrInvalidPrivateKey
	}

	decrypted, ok := box.OpenAnonymous(nil, sealedBox, pubKey, privKey)
	if !ok {
		return nil, domain.ErrDecryptionFailed
	}

	return decrypted, nil
}

// ValidateImage verifies magic bytes for supported image and video formats (JPEG, PNG, WebP, GIF, MP4, WebM, MOV)
func (s *SodiumCryptoService) ValidateImage(data []byte) (string, error) {
	if len(data) < 4 {
		return "", domain.ErrInvalidImage
	}

	// Check JPEG magic bytes: FF D8 FF
	if len(data) >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
		return "image/jpeg", nil
	}

	// Check PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
	pngMagic := []byte{0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}
	if len(data) >= 8 && bytes.Equal(data[:8], pngMagic) {
		return "image/png", nil
	}

	// Check WebP magic bytes: RIFF....WEBP
	if len(data) >= 12 && bytes.Equal(data[:4], []byte("RIFF")) && bytes.Equal(data[8:12], []byte("WEBP")) {
		return "image/webp", nil
	}

	// Check GIF magic bytes: GIF87a or GIF89a
	if len(data) >= 6 && (bytes.Equal(data[:6], []byte("GIF87a")) || bytes.Equal(data[:6], []byte("GIF89a"))) {
		return "image/gif", nil
	}

	// Check MP4 / QuickTime magic bytes: ....ftyp or ....moov
	if len(data) >= 8 && (bytes.Equal(data[4:8], []byte("ftyp")) || bytes.Equal(data[4:8], []byte("moov"))) {
		return "video/mp4", nil
	}

	// Check WebM / MKV magic bytes: 1A 45 DF A3
	if len(data) >= 4 && bytes.Equal(data[:4], []byte{0x1A, 0x45, 0xDF, 0xA3}) {
		return "video/webm", nil
	}

	// Check AVI magic bytes: RIFF....AVI
	if len(data) >= 12 && bytes.Equal(data[:4], []byte("RIFF")) && bytes.Equal(data[8:12], []byte("AVI ")) {
		return "video/x-msvideo", nil
	}

	// Fallback to http.DetectContentType
	detected := http.DetectContentType(data)
	if strings.HasPrefix(detected, "image/") || strings.HasPrefix(detected, "video/") {
		return detected, nil
	}

	return "", domain.ErrInvalidImage
}

func parse32ByteKey(s string) (*[32]byte, error) {
	var keyBytes []byte
	var err error

	// Try Hex (64 chars)
	if len(s) == 64 {
		keyBytes, err = hex.DecodeString(s)
	}

	// Try Base64 if hex decoding failed or length not 64
	if err != nil || len(keyBytes) != 32 {
		keyBytes, err = base64.StdEncoding.DecodeString(s)
		if err != nil {
			keyBytes, err = base64.RawURLEncoding.DecodeString(s)
		}
	}

	if err != nil || len(keyBytes) != 32 {
		return nil, domain.ErrInvalidPublicKey
	}

	var out [32]byte
	copy(out[:], keyBytes)
	return &out, nil
}
