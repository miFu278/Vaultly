package repository

import (
	"context"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type FolderRepository interface {
	Create(ctx context.Context, folder *entity.Folder) error
	GetByID(ctx context.Context, id, userID uuid.UUID) (*entity.Folder, error)
	ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Folder, error)
	Delete(ctx context.Context, id, userID uuid.UUID) error
}
