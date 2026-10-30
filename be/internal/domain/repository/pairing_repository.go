package repository

import (
	"context"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type PairingWithUser struct {
	Pairing   entity.Pairing
	UserEmail string
}

type PairingRepository interface {
	Create(ctx context.Context, pairing *entity.Pairing) error
	GetByToken(ctx context.Context, token string) (*PairingWithUser, error)
	CompletePairingTx(ctx context.Context, token string, userID uuid.UUID, wrappedKeys []entity.FileKey) error
}
