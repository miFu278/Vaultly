package dto

import (
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type InitUploadRequest struct {
	Size          int64      `json:"size" binding:"required,gt=0" example:"1048576"`
	ContentType   string     `json:"content_type" binding:"required" example:"image/jpeg"`
	Nonce         string     `json:"nonce" binding:"required" example:"dGVzdG5vbmNl"`
	FolderID      *uuid.UUID `json:"folder_id,omitempty" example:"00000000-0000-0000-0000-000000000000"`
	HasThumbnail  bool       `json:"has_thumbnail" example:"true"`
	ThumbnailSize int64      `json:"thumbnail_size,omitempty" example:"65536"`
}

type InitUploadResponse struct {
	FileID                uuid.UUID `json:"file_id"`
	PresignedURL          string    `json:"presigned_url"`
	R2ObjectKey           string    `json:"r2_object_key"`
	PresignedThumbnailURL string    `json:"presigned_thumbnail_url,omitempty"`
	R2ThumbnailKey        string    `json:"r2_thumbnail_key,omitempty"`
}

type DeviceWrappedKey struct {
	DeviceID   uuid.UUID `json:"device_id" binding:"required"`
	WrappedKey string    `json:"wrapped_key" binding:"required"`
}

type CompleteUploadRequest struct {
	WrappedKeys []DeviceWrappedKey `json:"wrapped_keys" binding:"required,dive"`
}

type FileDTO struct {
	ID             uuid.UUID         `json:"id"`
	UserID         uuid.UUID         `json:"user_id"`
	FolderID       *uuid.UUID        `json:"folder_id,omitempty"`
	R2ObjectKey    string            `json:"r2_object_key"`
	R2ThumbnailKey string            `json:"r2_thumbnail_key,omitempty"`
	Size           int64             `json:"size"`
	ContentType    string            `json:"content_type"`
	Nonce          string            `json:"nonce"`
	Status         entity.FileStatus `json:"status"`
	CreatedAt      time.Time         `json:"created_at"`
	UpdatedAt      time.Time         `json:"updated_at"`
}

type DownloadResponse struct {
	PresignedURL string `json:"presigned_url"`
	WrappedKey   string `json:"wrapped_key"`
	Nonce        string `json:"nonce"`
	ContentType  string `json:"content_type"`
	Size         int64  `json:"size"`
}

type ThumbnailResponse struct {
	PresignedURL string `json:"presigned_url"`
}

type PaginatedFilesResponse struct {
	Files      []FileDTO `json:"files"`
	NextCursor *string   `json:"next_cursor,omitempty"`
	HasMore    bool      `json:"has_more"`
}

// EncryptedImageUploadResponse returned when image is uploaded and encrypted via backend EncryptionService
type EncryptedImageUploadResponse struct {
	FileID      uuid.UUID `json:"file_id"`
	FileName    string    `json:"file_name"`
	ContentType string    `json:"content_type"`
	CipherSize  int64     `json:"cipher_size"`
	PlainSize   int64     `json:"plain_size"`
	Nonce       string    `json:"nonce"`
	ObjectKey   string    `json:"object_key"`
	Message     string    `json:"message"`
}

func ToFileDTO(f *entity.File) FileDTO {
	return FileDTO{
		ID:             f.ID,
		UserID:         f.UserID,
		FolderID:       f.FolderID,
		R2ObjectKey:    f.R2ObjectKey,
		R2ThumbnailKey: f.R2ThumbnailKey,
		Size:           f.Size,
		ContentType:    f.ContentType,
		Nonce:          f.Nonce,
		Status:         f.Status,
		CreatedAt:      f.CreatedAt,
		UpdatedAt:      f.UpdatedAt,
	}
}

func ToFileDTOList(files []entity.File) []FileDTO {
	list := make([]FileDTO, len(files))
	for i, f := range files {
		list[i] = ToFileDTO(&f)
	}
	return list
}
