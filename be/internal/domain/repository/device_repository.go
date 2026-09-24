package repository

import (
	"context"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type DeviceRepository interface {
	Create(ctx context.Context, device *entity.Device) error
	GetByID(ctx context.Context, id uuid.UUID) (*entity.Device, error)
	ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Device, error)
	Revoke(ctx context.Context, userID, deviceID uuid.UUID) error
}
