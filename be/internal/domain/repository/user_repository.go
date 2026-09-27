package repository

import (
	"context"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type UserRepository interface {
	Create(ctx context.Context, user *entity.User) error
	GetByID(ctx context.Context, id uuid.UUID) (*entity.User, error)
	GetByEmail(ctx context.Context, email string) (*entity.User, error)
	UpdatePIN(ctx context.Context, id uuid.UUID, pinHash string) error
}
