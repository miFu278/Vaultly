package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type FileRepository interface {
	Create(ctx context.Context, file *entity.File) error
	GetByID(ctx context.Context, id, userID uuid.UUID) (*entity.File, error)
	GetReadyByID(ctx context.Context, id, userID uuid.UUID) (*entity.File, error)
	ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.File, error)
	ListByFolder(ctx context.Context, userID uuid.UUID, folderID *uuid.UUID, cursor *time.Time, limit int) (files []entity.File, nextCursor *time.Time, hasMore bool, err error)
	UpdateStatus(ctx context.Context, id uuid.UUID, status entity.FileStatus) error
	UpdateFolderID(ctx context.Context, id, userID uuid.UUID, folderID *uuid.UUID) error
	CopyFile(ctx context.Context, id, userID uuid.UUID, targetFolderID *uuid.UUID) (*entity.File, error)
	Delete(ctx context.Context, id, userID uuid.UUID) (objectKey string, thumbnailKey string, err error)

	SaveFileKeys(ctx context.Context, fileID uuid.UUID, keys []entity.FileKey) error
	GetFileKey(ctx context.Context, fileID, deviceID uuid.UUID) (*entity.FileKey, error)
	GetFileKeysForDevice(ctx context.Context, deviceID uuid.UUID) ([]entity.FileKey, error)

	CompleteUploadTx(ctx context.Context, userID, fileID uuid.UUID, keys []entity.FileKey) error
}
