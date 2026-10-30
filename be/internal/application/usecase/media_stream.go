package usecase

import (
	"context"
	"encoding/hex"
	"fmt"
	"io"
	"strings"

	"github.com/google/uuid"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
)

// DecryptedMedia is a seekable plaintext view of one stored file. The caller must
// Close it: it holds an open storage stream.
type DecryptedMedia struct {
	Content     io.ReadSeeker
	ContentType string
	Size        int64
}

func (m *DecryptedMedia) Close() error {
	if c, ok := m.Content.(io.Closer); ok {
		return c.Close()
	}
	return nil
}

// OpenDecryptedMedia resolves the file key and returns a streaming, seekable
// plaintext reader for GET /files/{id}/view.
//
// Only the segment that holds a requested byte range is read and decrypted, so a
// video seek costs one segment instead of the whole object.
func (uc *FileUseCase) OpenDecryptedMedia(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	fileID uuid.UUID,
	devicePrivKeyHex ...string,
) (*DecryptedMedia, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, err
	}
	return uc.openMedia(ctx, file, file.R2ObjectKey, "", userID, deviceID, devicePrivKeyHex...)
}

// OpenDecryptedThumbnail is OpenDecryptedMedia for the small preview object.
func (uc *FileUseCase) OpenDecryptedThumbnail(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	fileID uuid.UUID,
	devicePrivKeyHex ...string,
) (*DecryptedMedia, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, err
	}
	if file.R2ThumbnailKey == "" {
		return nil, domain.ErrThumbnailNotFound
	}
	// Previews are always JPEG, whatever the original format is.
	return uc.openMedia(ctx, file, file.R2ThumbnailKey, "image/jpeg", userID, deviceID, devicePrivKeyHex...)
}

// openMedia builds the plaintext stream for one stored object of a file.
func (uc *FileUseCase) openMedia(
	ctx context.Context,
	file *entity.File,
	objectKey string,
	contentType string,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	devicePrivKeyHex ...string,
) (*DecryptedMedia, error) {
	rawKey, err := uc.resolveFileKey(ctx, userID, deviceID, file, devicePrivKeyHex...)
	if err != nil {
		return nil, err
	}

	cipher, cipherLen, err := uc.storage.GetObjectReader(ctx, objectKey)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve encrypted file from storage: %w", err)
	}
	fetch := func(offset, length int64) (io.ReadCloser, error) {
		return uc.storage.GetObjectRange(ctx, objectKey, offset, length)
	}
	stream, err := uc.crypto.OpenDecryptStream(rawKey, cipherLen, cipher, fetch)
	if err != nil {
		_ = cipher.Close()
		return nil, err
	}

	if contentType == "" {
		contentType = file.ContentType
	}
	return &DecryptedMedia{
		Content:     stream,
		ContentType: contentType,
		Size:        stream.Size(),
	}, nil
}

// resolveFileKey walks the key sources in precedence order: the wrapped key of
// the requesting device, any other device of the user, then the raw key that
// older uploads embedded in File.Nonce.
func (uc *FileUseCase) resolveFileKey(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	file *entity.File,
	devicePrivKeyHex ...string,
) ([]byte, error) {
	privKey := ""
	if len(devicePrivKeyHex) > 0 {
		privKey = devicePrivKeyHex[0]
	}

	// Fast path: a session without a device cannot unwrap anything, and the key
	// sits in the row itself. Without this the gallery paid two database round
	// trips per thumbnail for an answer it already had.
	if deviceID == nil {
		if key := keyFromNonce(file.Nonce); key != nil {
			return key, nil
		}
	}

	var rawKey []byte
	if deviceID != nil {
		if fk, err := uc.fileRepo.GetFileKey(ctx, file.ID, *deviceID); err == nil {
			rawKey = uc.unwrapKey(ctx, fk, privKey)
		}
	}

	if len(rawKey) == 0 {
		devices, _ := uc.deviceRepo.ListByUserID(ctx, userID)
		for _, dev := range devices {
			fk, err := uc.fileRepo.GetFileKey(ctx, file.ID, dev.ID)
			if err != nil {
				continue
			}
			if rawKey = uc.unwrapKey(ctx, fk, privKey); len(rawKey) == 32 {
				break
			}
		}
	}

	if len(rawKey) == 0 {
		rawKey = keyFromNonce(file.Nonce)
	}

	if len(rawKey) != 32 {
		return nil, domain.ErrDeviceUnauthorized
	}
	return rawKey, nil
}

// keyFromNonce reads the file key older uploads stored next to the stream header
// (format: headerHex:keyHex or keyHex).
func keyFromNonce(nonce string) []byte {
	if nonce == "" {
		return nil
	}
	parts := strings.Split(nonce, ":")
	key, err := hex.DecodeString(parts[len(parts)-1])
	if err != nil || len(key) != 32 {
		return nil
	}
	return key
}

// unwrapKey opens a sealed box when the caller supplied a private key, and falls
// back to the raw hex key older uploads stored instead of a sealed box.
func (uc *FileUseCase) unwrapKey(ctx context.Context, fk *entity.FileKey, privKey string) []byte {
	if privKey != "" {
		if dev, err := uc.deviceRepo.GetByID(ctx, fk.DeviceID); err == nil {
			if k, err := uc.crypto.UnwrapKeyForDevice(fk.WrappedKey, dev.PublicKey, privKey); err == nil && len(k) == 32 {
				return k
			}
		}
	}
	if k, err := hex.DecodeString(fk.WrappedKey); err == nil && len(k) == 32 {
		return k
	}
	return nil
}
