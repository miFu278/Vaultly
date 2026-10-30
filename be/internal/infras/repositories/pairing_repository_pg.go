package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type PairingRepositoryPG struct {
	pool *pgxpool.Pool
}

func NewPairingRepository(pool *pgxpool.Pool) repository.PairingRepository {
	return &PairingRepositoryPG{pool: pool}
}

func (r *PairingRepositoryPG) Create(ctx context.Context, p *entity.Pairing) error {
	query := `
		INSERT INTO pairings (pairing_token, public_key, device_name, status, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`
	return r.pool.QueryRow(ctx, query, p.PairingToken, p.PublicKey, p.DeviceName, p.Status, p.ExpiresAt, p.CreatedAt).
		Scan(&p.ID)
}

func (r *PairingRepositoryPG) GetByToken(ctx context.Context, token string) (*repository.PairingWithUser, error) {
	var p entity.Pairing
	var email string
	query := `
		SELECT p.id, p.pairing_token, p.public_key, p.device_name, p.status, p.user_id, p.created_device_id, p.expires_at, p.created_at, COALESCE(u.email, '')
		FROM pairings p
		LEFT JOIN users u ON p.user_id = u.id
		WHERE p.pairing_token = $1
	`
	err := r.pool.QueryRow(ctx, query, token).Scan(
		&p.ID, &p.PairingToken, &p.PublicKey, &p.DeviceName,
		&p.Status, &p.UserID, &p.CreatedDeviceID, &p.ExpiresAt, &p.CreatedAt, &email,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrPairingNotFound
		}
		return nil, err
	}

	if time.Now().After(p.ExpiresAt) && p.Status == entity.PairingStatusPending {
		p.Status = entity.PairingStatusExpired
	}

	return &repository.PairingWithUser{
		Pairing:   p,
		UserEmail: email,
	}, nil
}

func (r *PairingRepositoryPG) CompletePairingTx(ctx context.Context, token string, userID uuid.UUID, wrappedKeys []entity.FileKey) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Fetch pairing session for update
	var pairingID uuid.UUID
	var status string
	var expiresAt time.Time
	var publicKey, deviceName string
	query := `
		SELECT id, status, expires_at, public_key, device_name
		FROM pairings
		WHERE pairing_token = $1 FOR UPDATE
	`
	err = tx.QueryRow(ctx, query, token).Scan(&pairingID, &status, &expiresAt, &publicKey, &deviceName)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrPairingNotFound
		}
		return err
	}

	if status != string(entity.PairingStatusPending) {
		return domain.ErrPairingAlreadyProcessed
	}
	if time.Now().After(expiresAt) {
		return domain.ErrPairingExpired
	}

	// The new device's public key and name come from the pairing session it
	// started: other devices wrap file keys with this public key, so it must be
	// the caller's key rather than whatever the approving device sent.
	var deviceID uuid.UUID
	insertDevQuery := `
		INSERT INTO devices (user_id, public_key, name, created_at)
		VALUES ($1, $2, $3, NOW())
		RETURNING id
	`
	err = tx.QueryRow(ctx, insertDevQuery, userID, publicKey, deviceName).Scan(&deviceID)
	if err != nil {
		return err
	}

	// Insert wrapped keys for existing files for new device
	keyInsertQuery := `
		INSERT INTO file_keys (file_id, device_id, wrapped_key, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (file_id, device_id) DO UPDATE SET wrapped_key = EXCLUDED.wrapped_key
	`
	for _, wk := range wrappedKeys {
		_, err = tx.Exec(ctx, keyInsertQuery, wk.FileID, deviceID, wk.WrappedKey)
		if err != nil {
			return err
		}
	}

	// Mark pairing as completed
	updatePairingQuery := `
		UPDATE pairings
		SET status = 'completed', user_id = $1, created_device_id = $2
		WHERE id = $3
	`
	_, err = tx.Exec(ctx, updatePairingQuery, userID, deviceID, pairingID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}
