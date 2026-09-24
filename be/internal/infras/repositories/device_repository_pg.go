package repositories

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type DeviceRepositoryPG struct {
	pool *pgxpool.Pool
}

func NewDeviceRepository(pool *pgxpool.Pool) repository.DeviceRepository {
	return &DeviceRepositoryPG{pool: pool}
}

func (r *DeviceRepositoryPG) Create(ctx context.Context, device *entity.Device) error {
	query := `
		INSERT INTO devices (user_id, public_key, name, created_at)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, public_key, name, created_at, revoked_at
	`
	return r.pool.QueryRow(ctx, query, device.UserID, device.PublicKey, device.Name, device.CreatedAt).
		Scan(&device.ID, &device.UserID, &device.PublicKey, &device.Name, &device.CreatedAt, &device.RevokedAt)
}

func (r *DeviceRepositoryPG) GetByID(ctx context.Context, id uuid.UUID) (*entity.Device, error) {
	var dev entity.Device
	query := `
		SELECT id, user_id, public_key, name, created_at, revoked_at
		FROM devices
		WHERE id = $1
	`
	err := r.pool.QueryRow(ctx, query, id).
		Scan(&dev.ID, &dev.UserID, &dev.PublicKey, &dev.Name, &dev.CreatedAt, &dev.RevokedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrDeviceNotFound
		}
		return nil, err
	}
	return &dev, nil
}

func (r *DeviceRepositoryPG) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Device, error) {
	query := `
		SELECT id, user_id, public_key, name, created_at, revoked_at
		FROM devices
		WHERE user_id = $1 AND revoked_at IS NULL
		ORDER BY created_at ASC
	`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []entity.Device
	for rows.Next() {
		var dev entity.Device
		if err := rows.Scan(&dev.ID, &dev.UserID, &dev.PublicKey, &dev.Name, &dev.CreatedAt, &dev.RevokedAt); err != nil {
			return nil, err
		}
		devices = append(devices, dev)
	}

	if devices == nil {
		devices = []entity.Device{}
	}

	return devices, nil
}

func (r *DeviceRepositoryPG) Revoke(ctx context.Context, userID, deviceID uuid.UUID) error {
	query := `
		UPDATE devices
		SET revoked_at = NOW()
		WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL
	`
	tag, err := r.pool.Exec(ctx, query, deviceID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrDeviceNotFound
	}
	return nil
}
