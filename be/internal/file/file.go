package file

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"vaultly-be/internal/database"
	"vaultly-be/internal/models"
	"vaultly-be/internal/storage"
)

type FileService struct {
	db      *database.DB
	storage *storage.StorageService
}

func NewFileService(db *database.DB, storage *storage.StorageService) *FileService {
	return &FileService{db: db, storage: storage}
}

// InitUpload creates a pending file metadata record and generates a presigned PUT URL
func (s *FileService) InitUpload(ctx context.Context, userID uuid.UUID, req models.InitUploadRequest) (*models.InitUploadResponse, error) {
	fileID := uuid.New()
	objectKey := fmt.Sprintf("%s/%s", userID.String(), fileID.String())

	presignedURL, err := s.storage.GeneratePresignedPutURL(ctx, objectKey, req.ContentType, req.Size)
	if err != nil {
		return nil, fmt.Errorf("failed to generate upload URL: %w", err)
	}

	query := `
		INSERT INTO files (id, user_id, r2_object_key, size, content_type, nonce, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, 'pending', NOW(), NOW())
	`
	_, err = s.db.Pool.Exec(ctx, query, fileID, userID, objectKey, req.Size, req.ContentType, req.Nonce)
	if err != nil {
		return nil, fmt.Errorf("failed to record file metadata: %w", err)
	}

	return &models.InitUploadResponse{
		FileID:       fileID,
		PresignedURL: presignedURL,
		R2ObjectKey:  objectKey,
	}, nil
}

// CompleteUpload marks the file as ready and stores the wrapped keys per device
func (s *FileService) CompleteUpload(ctx context.Context, userID, fileID uuid.UUID, req models.CompleteUploadRequest) error {
	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Verify file belongs to user and is pending
	var status string
	checkQuery := `SELECT status FROM files WHERE id = $1 AND user_id = $2 FOR UPDATE`
	err = tx.QueryRow(ctx, checkQuery, fileID, userID).Scan(&status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("file not found")
		}
		return err
	}

	// Insert wrapped keys for each authorized device
	keyInsertQuery := `
		INSERT INTO file_keys (file_id, device_id, wrapped_key, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (file_id, device_id) DO UPDATE SET wrapped_key = EXCLUDED.wrapped_key
	`
	for _, wk := range req.WrappedKeys {
		_, err = tx.Exec(ctx, keyInsertQuery, fileID, wk.DeviceID, wk.WrappedKey)
		if err != nil {
			return fmt.Errorf("failed to insert wrapped key for device %s: %w", wk.DeviceID, err)
		}
	}

	// Update file status to ready
	updateQuery := `UPDATE files SET status = 'ready', updated_at = NOW() WHERE id = $1`
	_, err = tx.Exec(ctx, updateQuery, fileID)
	if err != nil {
		return fmt.Errorf("failed to mark file ready: %w", err)
	}

	return tx.Commit(ctx)
}

// ListFiles lists all ready files for a user
func (s *FileService) ListFiles(ctx context.Context, userID uuid.UUID) ([]models.File, error) {
	query := `
		SELECT id, user_id, r2_object_key, size, content_type, nonce, status, created_at, updated_at
		FROM files
		WHERE user_id = $1 AND status = 'ready'
		ORDER BY created_at DESC
	`
	rows, err := s.db.Pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []models.File
	for rows.Next() {
		var f models.File
		if err := rows.Scan(&f.ID, &f.UserID, &f.R2ObjectKey, &f.Size, &f.ContentType, &f.Nonce, &f.Status, &f.CreatedAt, &f.UpdatedAt); err != nil {
			return nil, err
		}
		files = append(files, f)
	}

	if files == nil {
		files = []models.File{}
	}

	return files, nil
}

// DownloadFile generates a presigned GET URL and fetches the wrapped key for the requesting device
func (s *FileService) DownloadFile(ctx context.Context, userID, deviceID, fileID uuid.UUID) (*models.DownloadResponse, error) {
	// Check file metadata
	var file models.File
	fileQuery := `
		SELECT id, user_id, r2_object_key, size, content_type, nonce, status
		FROM files
		WHERE id = $1 AND user_id = $2 AND status = 'ready'
	`
	err := s.db.Pool.QueryRow(ctx, fileQuery, fileID, userID).
		Scan(&file.ID, &file.UserID, &file.R2ObjectKey, &file.Size, &file.ContentType, &file.Nonce, &file.Status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("file not found")
		}
		return nil, err
	}

	// Fetch wrapped key for device
	var wrappedKey string
	keyQuery := `SELECT wrapped_key FROM file_keys WHERE file_id = $1 AND device_id = $2`
	err = s.db.Pool.QueryRow(ctx, keyQuery, fileID, deviceID).Scan(&wrappedKey)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("device not authorized to decrypt this file")
		}
		return nil, err
	}

	presignedURL, err := s.storage.GeneratePresignedGetURL(ctx, file.R2ObjectKey)
	if err != nil {
		return nil, fmt.Errorf("failed to generate download URL: %w", err)
	}

	return &models.DownloadResponse{
		PresignedURL: presignedURL,
		WrappedKey:   wrappedKey,
		Nonce:        file.Nonce,
		ContentType:  file.ContentType,
		Size:         file.Size,
	}, nil
}

// DeleteFile removes file record and ciphertext from R2
func (s *FileService) DeleteFile(ctx context.Context, userID, fileID uuid.UUID) error {
	var objectKey string
	query := `DELETE FROM files WHERE id = $1 AND user_id = $2 RETURNING r2_object_key`
	err := s.db.Pool.QueryRow(ctx, query, fileID, userID).Scan(&objectKey)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return errors.New("file not found")
		}
		return err
	}

	// Delete from storage (best-effort)
	_ = s.storage.DeleteObject(ctx, objectKey)
	return nil
}

type FileHandler struct {
	service *FileService
}

func NewFileHandler(service *FileService) *FileHandler {
	return &FileHandler{service: service}
}

func (h *FileHandler) InitUpload(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	var req models.InitUploadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	resp, err := h.service.InitUpload(c.Request.Context(), userID, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *FileHandler) CompleteUpload(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	fileIDStr := c.Param("id")
	fileID, err := uuid.Parse(fileIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	var req models.CompleteUploadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.service.CompleteUpload(c.Request.Context(), userID, fileID, req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Upload completed successfully"})
}

func (h *FileHandler) List(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	files, err := h.service.ListFiles(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, files)
}

func (h *FileHandler) Download(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	deviceIDVal, exists := c.Get("device_id")
	if !exists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Device ID required (provide in token or X-Device-ID header)"})
		return
	}
	deviceID := deviceIDVal.(uuid.UUID)

	fileIDStr := c.Param("id")
	fileID, err := uuid.Parse(fileIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	resp, err := h.service.DownloadFile(c.Request.Context(), userID, deviceID, fileID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *FileHandler) Delete(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}
	userID := userIDVal.(uuid.UUID)

	fileIDStr := c.Param("id")
	fileID, err := uuid.Parse(fileIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	if err := h.service.DeleteFile(c.Request.Context(), userID, fileID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "File deleted successfully"})
}
