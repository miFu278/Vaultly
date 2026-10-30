package repositories

import (
	"context"
	"errors"
	"log"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type UserRepositoryPG struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) repository.UserRepository {
	return &UserRepositoryPG{pool: pool}
}

func (r *UserRepositoryPG) Create(ctx context.Context, user *entity.User) error {
	query := `
		INSERT INTO users (email, password_hash, created_at, updated_at)
		VALUES ($1, $2, $3, $4)
		RETURNING id, email, storage_quota_bytes, created_at, updated_at
	`
	err := r.pool.QueryRow(ctx, query, user.Email, user.PasswordHash, user.CreatedAt, user.UpdatedAt).
		Scan(&user.ID, &user.Email, &user.StorageQuotaBytes, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		log.Printf("[UserRepositoryPG.Create] DB Error: %v", err)
		return domain.ErrEmailAlreadyExists
	}
	return nil
}

func (r *UserRepositoryPG) GetByID(ctx context.Context, id uuid.UUID) (*entity.User, error) {
	var user entity.User
	query := `SELECT id, email, password_hash, COALESCE(pin_hash, ''), storage_quota_bytes, created_at, updated_at FROM users WHERE id = $1`
	err := r.pool.QueryRow(ctx, query, id).
		Scan(&user.ID, &user.Email, &user.PasswordHash, &user.PINHash, &user.StorageQuotaBytes, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (r *UserRepositoryPG) GetByEmail(ctx context.Context, email string) (*entity.User, error) {
	var user entity.User
	query := `SELECT id, email, password_hash, COALESCE(pin_hash, ''), storage_quota_bytes, created_at, updated_at FROM users WHERE email = $1`
	err := r.pool.QueryRow(ctx, query, email).
		Scan(&user.ID, &user.Email, &user.PasswordHash, &user.PINHash, &user.StorageQuotaBytes, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrUserNotFound
		}
		return nil, err
	}
	return &user, nil
}

func (r *UserRepositoryPG) UpdatePIN(ctx context.Context, id uuid.UUID, pinHash string) error {
	query := `UPDATE users SET pin_hash = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.pool.Exec(ctx, query, pinHash, id)
	return err
}
