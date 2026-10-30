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

	// MarkDeleted hides a file and returns the storage keys it uses plus whether
	// another live record still points at them: copies share one storage object,
	// so the object may only go once the last record is gone.
	MarkDeleted(ctx context.Context, id, userID uuid.UUID) (objectKey string, thumbnailKey string, shared bool, err error)

	// Purge drops the metadata row of a file that MarkDeleted already hid.
	Purge(ctx context.Context, id, userID uuid.UUID) error

	// Usage is the summed size of the user's live files, split by media kind.
	Usage(ctx context.Context, userID uuid.UUID) (entity.FileUsage, error)

	SaveFileKeys(ctx context.Context, fileID uuid.UUID, keys []entity.FileKey) error
	GetFileKey(ctx context.Context, fileID, deviceID uuid.UUID) (*entity.FileKey, error)
	GetFileKeysForDevice(ctx context.Context, deviceID uuid.UUID) ([]entity.FileKey, error)

	CompleteUploadTx(ctx context.Context, userID, fileID uuid.UUID, keys []entity.FileKey) error
}
