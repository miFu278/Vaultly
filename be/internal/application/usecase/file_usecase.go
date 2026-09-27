package usecase

import (
	"context"
	"encoding/hex"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
	"vaultly-be/internal/domain/service"
)

type FileUseCase struct {
	fileRepo   repository.FileRepository
	deviceRepo repository.DeviceRepository
	storage    service.ObjectStorage
	crypto     service.EncryptionService
}

func NewFileUseCase(
	fileRepo repository.FileRepository,
	deviceRepo repository.DeviceRepository,
	storage service.ObjectStorage,
	crypto service.EncryptionService,
) *FileUseCase {
	return &FileUseCase{
		fileRepo:   fileRepo,
		deviceRepo: deviceRepo,
		storage:    storage,
		crypto:     crypto,
	}
}

// InitUpload creates a pending file metadata record and generates presigned PUT URLs for full-res and thumbnail
func (uc *FileUseCase) InitUpload(ctx context.Context, userID uuid.UUID, req dto.InitUploadRequest) (*dto.InitUploadResponse, error) {
	fileID := uuid.New()
	objectKey := fmt.Sprintf("%s/%s", userID.String(), fileID.String())

	presignedURL, err := uc.storage.GeneratePresignedPutURL(ctx, objectKey, req.ContentType, req.Size)
	if err != nil {
		return nil, fmt.Errorf("failed to generate upload URL: %w", err)
	}

	var presignedThumbURL string
	var thumbObjectKey string
	if req.HasThumbnail {
		thumbObjectKey = fmt.Sprintf("%s/%s_thumb", userID.String(), fileID.String())
		thumbSize := req.ThumbnailSize
		if thumbSize <= 0 {
			thumbSize = 256 * 1024 // 256KB default thumb size limit
		}
		pURL, err := uc.storage.GeneratePresignedPutURL(ctx, thumbObjectKey, req.ContentType, thumbSize)
		if err == nil {
			presignedThumbURL = pURL
		}
	}

	file := entity.File{
		ID:             fileID,
		UserID:         userID,
		FolderID:       req.FolderID,
		R2ObjectKey:    objectKey,
		R2ThumbnailKey: thumbObjectKey,
		Size:           req.Size,
		ContentType:    req.ContentType,
		Nonce:          req.Nonce,
		Status:         entity.FileStatusPending,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	if err := uc.fileRepo.Create(ctx, &file); err != nil {
		return nil, fmt.Errorf("failed to record file metadata: %w", err)
	}

	return &dto.InitUploadResponse{
		FileID:                fileID,
		PresignedURL:          presignedURL,
		R2ObjectKey:           objectKey,
		PresignedThumbnailURL: presignedThumbURL,
		R2ThumbnailKey:        thumbObjectKey,
	}, nil
}

// CompleteUpload marks the file as ready and stores the wrapped keys per device
func (uc *FileUseCase) CompleteUpload(ctx context.Context, userID, fileID uuid.UUID, req dto.CompleteUploadRequest) error {
	var keys []entity.FileKey
	for _, wk := range req.WrappedKeys {
		keys = append(keys, entity.FileKey{
			FileID:     fileID,
			DeviceID:   wk.DeviceID,
			WrappedKey: wk.WrappedKey,
			CreatedAt:  time.Now(),
		})
	}

	return uc.fileRepo.CompleteUploadTx(ctx, userID, fileID, keys)
}

// ListFiles lists all ready files for a user
func (uc *FileUseCase) ListFiles(ctx context.Context, userID uuid.UUID) ([]dto.FileDTO, error) {
	files, err := uc.fileRepo.ListByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return dto.ToFileDTOList(files), nil
}

// ListFilesByFolder performs cursor-based pagination per folder (20-30 items per page)
func (uc *FileUseCase) ListFilesByFolder(ctx context.Context, userID uuid.UUID, folderID *uuid.UUID, cursorStr string, limit int) (*dto.PaginatedFilesResponse, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}

	var cursor *time.Time
	if cursorStr != "" {
		t, err := time.Parse(time.RFC3339Nano, cursorStr)
		if err != nil {
			t, err = time.Parse(time.RFC3339, cursorStr)
		}
		if err == nil {
			cursor = &t
		}
	}

	files, nextCur, hasMore, err := uc.fileRepo.ListByFolder(ctx, userID, folderID, cursor, limit)
	if err != nil {
		return nil, err
	}

	var nextCursorStr *string
	if nextCur != nil {
		s := nextCur.Format(time.RFC3339Nano)
		nextCursorStr = &s
	}

	return &dto.PaginatedFilesResponse{
		Files:      dto.ToFileDTOList(files),
		NextCursor: nextCursorStr,
		HasMore:    hasMore,
	}, nil
}

// DownloadFile generates a presigned GET URL and fetches the wrapped key for the requesting device
func (uc *FileUseCase) DownloadFile(ctx context.Context, userID, deviceID, fileID uuid.UUID) (*dto.DownloadResponse, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, err
	}

	wrappedKey := ""
	fk, err := uc.fileRepo.GetFileKey(ctx, fileID, deviceID)
	if err == nil {
		wrappedKey = fk.WrappedKey
	} else {
		// Fallback: if no device key registered, extract key from file.Nonce
		parts := strings.Split(file.Nonce, ":")
		if len(parts) >= 2 {
			wrappedKey = parts[1]
		} else {
			wrappedKey = file.Nonce
		}
	}

	presignedURL, err := uc.storage.GeneratePresignedGetURL(ctx, file.R2ObjectKey)
	if err != nil {
		return nil, fmt.Errorf("failed to generate download URL: %w", err)
	}

	nonce := file.Nonce
	if strings.Contains(file.Nonce, ":") {
		nonce = strings.Split(file.Nonce, ":")[0]
	}

	return &dto.DownloadResponse{
		PresignedURL: presignedURL,
		WrappedKey:   wrappedKey,
		Nonce:        nonce,
		ContentType:  file.ContentType,
		Size:         file.Size,
	}, nil
}

// GetThumbnail generates a presigned GET URL for the fast gallery thumbnail
func (uc *FileUseCase) GetThumbnail(ctx context.Context, userID, fileID uuid.UUID) (*dto.ThumbnailResponse, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, err
	}

	if file.R2ThumbnailKey == "" {
		return nil, fmt.Errorf("file does not have an attached thumbnail")
	}

	presignedURL, err := uc.storage.GeneratePresignedGetURL(ctx, file.R2ThumbnailKey)
	if err != nil {
		return nil, fmt.Errorf("failed to generate thumbnail download URL: %w", err)
	}

	return &dto.ThumbnailResponse{
		PresignedURL: presignedURL,
	}, nil
}

// DeleteFile removes file record and both full-res and thumbnail ciphertext from storage
func (uc *FileUseCase) DeleteFile(ctx context.Context, userID, fileID uuid.UUID) error {
	objectKey, thumbKey, err := uc.fileRepo.Delete(ctx, idOrNil(fileID), userID)
	if err != nil {
		return err
	}

	_ = uc.storage.DeleteObject(ctx, objectKey)
	if thumbKey != "" {
		_ = uc.storage.DeleteObject(ctx, thumbKey)
	}
	return nil
}

// UploadEncryptedImage handles direct server-side image encryption & storage upload:
// 1. Validates image magic bytes (JPEG/PNG/WebP/GIF)
// 2. Generates 256-bit AES File Key and 96-bit GCM Nonce
// 3. Encrypts image bytes via EncryptionService
// 4. Stores encrypted ciphertext into Object Storage
// 5. Wraps key for active user devices
// 6. Creates File record with status 'ready'
func (uc *FileUseCase) UploadEncryptedImage(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	fileName string,
	rawImage []byte,
	folderID ...*uuid.UUID,
) (*dto.EncryptedImageUploadResponse, error) {
	if len(rawImage) == 0 {
		return nil, domain.ErrInvalidImage
	}

	var targetFolderID *uuid.UUID
	if len(folderID) > 0 {
		targetFolderID = folderID[0]
	}

	// 1. Validate image format
	detectedMime, err := uc.crypto.ValidateImage(rawImage)
	if err != nil {
		return nil, err
	}

	// 2. Generate 32-byte (256-bit) File Key
	fileKey, err := uc.crypto.GenerateFileKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate encryption File Key: %w", err)
	}

	// 3. Encrypt the raw image via libsodium crypto_secretstream_xchacha20poly1305
	ciphertext, header, err := uc.crypto.EncryptBytes(rawImage, fileKey)
	if err != nil {
		return nil, fmt.Errorf("encryption error: %w", err)
	}

	fileID := uuid.New()
	objectKey := fmt.Sprintf("%s/%s", userID.String(), fileID.String())
	headerHex := hex.EncodeToString(header)
	keyHex := hex.EncodeToString(fileKey)
	combinedNonce := fmt.Sprintf("%s:%s", headerHex, keyHex)

	// 4. Put ciphertext directly to storage
	if err := uc.storage.PutObject(ctx, objectKey, ciphertext, "application/octet-stream"); err != nil {
		return nil, fmt.Errorf("storage error: %w", err)
	}

	// 5. Create database record
	fileEntity := entity.File{
		ID:          fileID,
		UserID:      userID,
		FolderID:    targetFolderID,
		R2ObjectKey: objectKey,
		Size:        int64(len(ciphertext)),
		ContentType: detectedMime,
		Nonce:       combinedNonce,
		Status:      entity.FileStatusReady,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := uc.fileRepo.Create(ctx, &fileEntity); err != nil {
		_ = uc.storage.DeleteObject(ctx, objectKey)
		return nil, fmt.Errorf("failed to save encrypted file metadata: %w", err)
	}

	// 6. Wrap File Key for all authorized devices using crypto_box_seal (X25519)
	devices, err := uc.deviceRepo.ListByUserID(ctx, userID)
	if err == nil && len(devices) > 0 {
		var fileKeys []entity.FileKey
		for _, dev := range devices {
			wrapped, err := uc.crypto.WrapKeyForDevice(fileKey, dev.PublicKey)
			if err == nil {
				fileKeys = append(fileKeys, entity.FileKey{
					FileID:     fileID,
					DeviceID:   dev.ID,
					WrappedKey: wrapped,
					CreatedAt:  time.Now(),
				})
			}
		}
		if len(fileKeys) > 0 {
			_ = uc.fileRepo.SaveFileKeys(ctx, fileID, fileKeys)
		}
	} else if deviceID != nil {
		// Fallback if device has no registered public key: encode raw key
		_ = uc.fileRepo.SaveFileKeys(ctx, fileID, []entity.FileKey{
			{
				FileID:     fileID,
				DeviceID:   *deviceID,
				WrappedKey: hex.EncodeToString(fileKey),
				CreatedAt:  time.Now(),
			},
		})
	}

	return &dto.EncryptedImageUploadResponse{
		FileID:      fileID,
		FileName:    fileName,
		ContentType: detectedMime,
		CipherSize:  int64(len(ciphertext)),
		PlainSize:   int64(len(rawImage)),
		Nonce:       headerHex,
		ObjectKey:   objectKey,
		Message:     "Image successfully validated, chunk-encrypted with crypto_secretstream_xchacha20poly1305, and stored",
	}, nil
}

// DownloadAndDecryptImage fetches encrypted ciphertext from storage and decrypts
// using libsodium crypto_secretstream_xchacha20poly1305
func (uc *FileUseCase) DownloadAndDecryptImage(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	fileID uuid.UUID,
	devicePrivKeyHex ...string,
) ([]byte, string, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, "", err
	}

	var rawKey []byte
	privKey := ""
	if len(devicePrivKeyHex) > 0 {
		privKey = devicePrivKeyHex[0]
	}

	// Try unwrapping for requesting device
	if deviceID != nil {
		fk, err := uc.fileRepo.GetFileKey(ctx, fileID, *deviceID)
		if err == nil {
			if privKey != "" {
				dev, devErr := uc.deviceRepo.GetByID(ctx, *deviceID)
				if devErr == nil {
					rawKey, _ = uc.crypto.UnwrapKeyForDevice(fk.WrappedKey, dev.PublicKey, privKey)
				}
			}
			if len(rawKey) == 0 {
				// Raw fallback
				k, _ := hex.DecodeString(fk.WrappedKey)
				if len(k) == 32 {
					rawKey = k
				}
			}
		}
	}

	// Fallback check all user devices
	if len(rawKey) == 0 {
		devices, _ := uc.deviceRepo.ListByUserID(ctx, userID)
		for _, dev := range devices {
			fk, err := uc.fileRepo.GetFileKey(ctx, fileID, dev.ID)
			if err == nil {
				if privKey != "" {
					k, err := uc.crypto.UnwrapKeyForDevice(fk.WrappedKey, dev.PublicKey, privKey)
					if err == nil && len(k) == 32 {
						rawKey = k
						break
					}
				}
				k, _ := hex.DecodeString(fk.WrappedKey)
				if len(k) == 32 {
					rawKey = k
					break
				}
			}
		}
	}

	// Fallback check if key was stored in file.Nonce (format: headerHex:keyHex or keyHex)
	if len(rawKey) == 0 && file.Nonce != "" {
		parts := strings.Split(file.Nonce, ":")
		if len(parts) >= 2 {
			if k, err := hex.DecodeString(parts[1]); err == nil && len(k) == 32 {
				rawKey = k
			}
		} else if len(parts) == 1 {
			if k, err := hex.DecodeString(parts[0]); err == nil && len(k) == 32 {
				rawKey = k
			}
		}
	}

	if len(rawKey) != 32 {
		return nil, "", domain.ErrDeviceUnauthorized
	}

	// Download ciphertext from storage
	ciphertext, _, err := uc.storage.GetObject(ctx, file.R2ObjectKey)
	if err != nil {
		return nil, "", fmt.Errorf("failed to retrieve encrypted file from storage: %w", err)
	}

	plaintext, err := uc.crypto.DecryptBytes(ciphertext, rawKey)
	if err != nil {
		return nil, "", err
	}

	return plaintext, file.ContentType, nil
}

func idOrNil(id uuid.UUID) uuid.UUID {
	return id
}

// MoveFileToFolder changes the folder_id of a file
func (uc *FileUseCase) MoveFileToFolder(ctx context.Context, userID, fileID uuid.UUID, folderID *uuid.UUID) error {
	return uc.fileRepo.UpdateFolderID(ctx, fileID, userID, folderID)
}

