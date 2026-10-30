package usecase

import (
	"bytes"
	"context"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
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
	thumbnails service.Thumbnailer
}

func NewFileUseCase(
	fileRepo repository.FileRepository,
	deviceRepo repository.DeviceRepository,
	storage service.ObjectStorage,
	crypto service.EncryptionService,
	thumbnails service.Thumbnailer,
) *FileUseCase {
	return &FileUseCase{
		fileRepo:   fileRepo,
		deviceRepo: deviceRepo,
		storage:    storage,
		crypto:     crypto,
		thumbnails: thumbnails,
	}
}

// InitUpload creates a pending file metadata record and generates presigned PUT URLs for full-res and thumbnail
func (uc *FileUseCase) InitUpload(ctx context.Context, userID uuid.UUID, req dto.InitUploadRequest) (*dto.InitUploadResponse, error) {
	if req.Size <= 0 {
		return nil, errors.New("size must be greater than zero")
	}
	if strings.TrimSpace(req.ContentType) == "" {
		return nil, errors.New("content_type is required")
	}

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

// GetFile returns the metadata of one ready file owned by the caller.
func (uc *FileUseCase) GetFile(ctx context.Context, userID, fileID uuid.UUID) (*dto.FileDTO, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, err
	}
	res := dto.ToFileDTO(file)
	return &res, nil
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

// DownloadFile generates a presigned GET URL and the file key wrapped for the
// requesting device. It never returns an unwrapped key: a caller without a
// wrapped key for this file is not authorized to read it.
func (uc *FileUseCase) DownloadFile(ctx context.Context, userID, deviceID, fileID uuid.UUID) (*dto.DownloadResponse, error) {
	file, err := uc.fileRepo.GetReadyByID(ctx, fileID, userID)
	if err != nil {
		return nil, err
	}

	fk, err := uc.fileRepo.GetFileKey(ctx, fileID, deviceID)
	if err != nil {
		return nil, domain.ErrDeviceUnauthorized
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
		WrappedKey:   fk.WrappedKey,
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

// DeleteFile removes the ciphertext and then the metadata record. The record is
// hidden first and only dropped once storage has confirmed the delete, so a
// storage failure stays retryable instead of leaving an unreferenced object.
func (uc *FileUseCase) DeleteFile(ctx context.Context, userID, fileID uuid.UUID) error {
	objectKey, thumbKey, shared, err := uc.fileRepo.MarkDeleted(ctx, fileID, userID)
	if err != nil {
		return err
	}

	if !shared {
		if err := uc.storage.DeleteObject(ctx, objectKey); err != nil {
			return fmt.Errorf("failed to delete file ciphertext (retry to finish): %w", err)
		}
		if thumbKey != "" {
			if err := uc.storage.DeleteObject(ctx, thumbKey); err != nil {
				return fmt.Errorf("failed to delete thumbnail ciphertext (retry to finish): %w", err)
			}
		}
	}

	return uc.fileRepo.Purge(ctx, fileID, userID)
}

// UploadEncryptedImage handles direct server-side image encryption & storage upload:
// 1. Validates image magic bytes (JPEG/PNG/WebP/GIF)
// 2. Generates a 256-bit File Key
// 3. Encrypts image bytes via EncryptionService
// 4. Stores encrypted ciphertext into Object Storage
// 5. Wraps key for active user devices
// 6. Creates File record with status 'ready'
//
// It buffers the whole payload, so it is only for the small Base64 JSON endpoint
// and tests; multipart uploads go through UploadEncryptedStream.
func (uc *FileUseCase) UploadEncryptedImage(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	fileName string,
	rawImage []byte,
	folderID ...*uuid.UUID,
) (*dto.EncryptedImageUploadResponse, error) {
	var targetFolderID *uuid.UUID
	if len(folderID) > 0 {
		targetFolderID = folderID[0]
	}
	return uc.UploadEncryptedStream(ctx, userID, deviceID, fileName, bytes.NewReader(rawImage), func() (service.ReadSeekCloser, error) {
		return readSeekNopCloser{bytes.NewReader(rawImage)}, nil
	}, targetFolderID)
}

// readSeekNopCloser adapts an in-memory reader to the replay contract.
type readSeekNopCloser struct{ io.ReadSeeker }

func (readSeekNopCloser) Close() error { return nil }

// countingReader tracks how many plaintext bytes were read so the upload can
// report and store the plaintext size without trusting the client.
type countingReader struct {
	r io.Reader
	n int64
}

func (c *countingReader) Read(p []byte) (int, error) {
	n, err := c.r.Read(p)
	c.n += int64(n)
	return n, err
}

// maxThumbnailSourceBytes bounds the plaintext the thumbnailer is asked to
// decode; larger uploads are videos or oversized stills and just skip it.
const maxThumbnailSourceBytes int64 = 25 << 20

// UploadEncryptedStream validates, encrypts and stores a media stream of any size.
//
// Nothing is buffered in memory: the ciphertext is spooled to a temporary file
// so the storage client gets an exact length and a seekable body (the segmented
// encryption writes its header last). replay, when not nil, re-opens the same
// plaintext for the thumbnail pass.
func (uc *FileUseCase) UploadEncryptedStream(
	ctx context.Context,
	userID uuid.UUID,
	deviceID *uuid.UUID,
	fileName string,
	src io.Reader,
	replay func() (service.ReadSeekCloser, error),
	targetFolderID *uuid.UUID,
) (*dto.EncryptedImageUploadResponse, error) {
	// 1. Validate the format from the magic bytes, then keep them for encryption.
	head := make([]byte, 512)
	headN, err := io.ReadFull(src, head)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return nil, fmt.Errorf("failed to read upload: %w", err)
	}
	head = head[:headN]

	detectedMime, err := uc.crypto.ValidateImage(head)
	if err != nil {
		return nil, err
	}

	// 2. Generate 32-byte (256-bit) File Key
	fileKey, err := uc.crypto.GenerateFileKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate encryption File Key: %w", err)
	}

	// 3. Encrypt the stream as independent segments so a later range request only
	// has to read one segment.
	// shortcut: the ciphertext is spooled to a temp file because the S3 client
	// needs a known content length and a seekable body; swap for a streamed
	// multipart upload if temp disk becomes the bottleneck.
	tmp, err := os.CreateTemp("", "vaultly-upload-*")
	if err != nil {
		return nil, fmt.Errorf("failed to allocate upload buffer: %w", err)
	}
	defer func() {
		_ = tmp.Close()
		_ = os.Remove(tmp.Name())
	}()

	plainSize, streamHeader, err := uc.crypto.EncryptSegmentedStream(io.MultiReader(bytes.NewReader(head), src), tmp, fileKey)
	if err != nil {
		return nil, fmt.Errorf("encryption error: %w", err)
	}

	cipherSize, err := tmp.Seek(0, io.SeekEnd)
	if err != nil {
		return nil, fmt.Errorf("failed to size encrypted upload: %w", err)
	}

	fileID := uuid.New()
	cleanName := filepath.Base(fileName)
	if cleanName == "." || cleanName == "/" || cleanName == "" {
		cleanName = fileID.String()
	}
	objectKey := fmt.Sprintf("%s/%s_%s", userID.String(), fileID.String(), cleanName)

	// The nonce column keeps the "header:key" shape older clients parse: the first
	// segment's stream header plus the file key shared by every segment.
	// shortcut: this stores the file key in the metadata row, so the vault is
	// server-trusted rather than end-to-end encrypted; uploads must move to
	// client-side encryption (POST /files/init + presigned PUT) and drop the key
	// from this column before the E2EE claim in the docs holds.
	combinedNonce := fmt.Sprintf("%s:%s", hex.EncodeToString(streamHeader), hex.EncodeToString(fileKey))

	// 4. Stream the ciphertext into storage
	if _, err := tmp.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to rewind encrypted upload: %w", err)
	}
	if err := uc.storage.PutObjectReader(ctx, objectKey, tmp, cipherSize, "application/octet-stream"); err != nil {
		return nil, fmt.Errorf("storage error: %w", err)
	}

	// 5. Best-effort preview so galleries never pull the full-resolution object.
	thumbKey := uc.storeThumbnail(ctx, objectKey, detectedMime, plainSize, fileKey, replay)

	// 6. Create database record (Size is the plaintext size, like InitUpload)
	fileEntity := entity.File{
		ID:             fileID,
		UserID:         userID,
		FolderID:       targetFolderID,
		R2ObjectKey:    objectKey,
		R2ThumbnailKey: thumbKey,
		Size:           plainSize,
		ContentType:    detectedMime,
		Nonce:          combinedNonce,
		Status:         entity.FileStatusReady,
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	if err := uc.fileRepo.Create(ctx, &fileEntity); err != nil {
		_ = uc.storage.DeleteObject(ctx, objectKey)
		if thumbKey != "" {
			_ = uc.storage.DeleteObject(ctx, thumbKey)
		}
		return nil, fmt.Errorf("failed to save encrypted file metadata: %w", err)
	}

	// 7. Wrap File Key for all authorized devices using crypto_box_seal (X25519)
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
		CipherSize:  cipherSize,
		PlainSize:   plainSize,
		Nonce:       hex.EncodeToString(streamHeader),
		ObjectKey:   objectKey,
		Message:     "Media successfully validated, chunk-encrypted with crypto_secretstream_xchacha20poly1305, and stored",
	}, nil
}

// storeThumbnail re-reads the plaintext, builds a small JPEG preview, encrypts it
// with the file key under a fresh secretstream header, and stores it next to the
// original. It returns the thumbnail object key, or "" when there is none.
func (uc *FileUseCase) storeThumbnail(
	ctx context.Context,
	objectKey string,
	mimeType string,
	plainSize int64,
	fileKey []byte,
	replay func() (service.ReadSeekCloser, error),
) string {
	if uc.thumbnails == nil || replay == nil || plainSize <= 0 || plainSize > maxThumbnailSourceBytes {
		return ""
	}
	if !strings.HasPrefix(mimeType, "image/") {
		return "" // videos need a decoder this service does not ship
	}

	src, err := replay()
	if err != nil {
		log.Printf("thumbnail skipped for %s: %v", objectKey, err)
		return ""
	}
	defer src.Close()

	jpegData, err := uc.thumbnails.Generate(src)
	if err != nil {
		log.Printf("thumbnail skipped for %s: %v", objectKey, err)
		return ""
	}
	if len(jpegData) == 0 {
		return ""
	}

	// A fresh random header per object keeps the shared file key safe.
	cipher, _, err := uc.crypto.EncryptBytes(jpegData, fileKey)
	if err != nil {
		log.Printf("thumbnail encryption failed for %s: %v", objectKey, err)
		return ""
	}

	thumbKey := objectKey + "_thumb"
	if err := uc.storage.PutObjectReader(ctx, thumbKey, bytes.NewReader(cipher), int64(len(cipher)), "application/octet-stream"); err != nil {
		log.Printf("thumbnail upload failed for %s: %v", objectKey, err)
		return ""
	}
	return thumbKey
}

// MoveFileToFolder changes the folder_id of a file
func (uc *FileUseCase) MoveFileToFolder(ctx context.Context, userID, fileID uuid.UUID, folderID *uuid.UUID) error {
	return uc.fileRepo.UpdateFolderID(ctx, fileID, userID, folderID)
}

// CopyFileToFolder creates a duplicate entry of a file in the destination folder
func (uc *FileUseCase) CopyFileToFolder(ctx context.Context, userID, fileID uuid.UUID, folderID *uuid.UUID) (*dto.FileDTO, error) {
	f, err := uc.fileRepo.CopyFile(ctx, fileID, userID, folderID)
	if err != nil {
		return nil, err
	}
	return &dto.FileDTO{
		ID:             f.ID,
		FolderID:       f.FolderID,
		R2ObjectKey:    f.R2ObjectKey,
		R2ThumbnailKey: f.R2ThumbnailKey,
		Size:           f.Size,
		ContentType:    f.ContentType,
		Status:         f.Status,
		CreatedAt:      f.CreatedAt,
		UpdatedAt:      f.UpdatedAt,
	}, nil
}

// BatchDeleteFiles deletes multiple files
func (uc *FileUseCase) BatchDeleteFiles(ctx context.Context, userID uuid.UUID, fileIDs []uuid.UUID) ([]uuid.UUID, []string) {
	var deleted []uuid.UUID
	var errMsgs []string
	for _, id := range fileIDs {
		if err := uc.DeleteFile(ctx, userID, id); err != nil {
			errMsgs = append(errMsgs, fmt.Sprintf("%s: %v", id.String(), err))
		} else {
			deleted = append(deleted, id)
		}
	}
	return deleted, errMsgs
}
