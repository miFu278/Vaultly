package repositories

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type FolderRepositoryPG struct {
	pool *pgxpool.Pool
}

func NewFolderRepository(pool *pgxpool.Pool) repository.FolderRepository {
	return &FolderRepositoryPG{pool: pool}
}

func (r *FolderRepositoryPG) Create(ctx context.Context, f *entity.Folder) error {
	query := `
		INSERT INTO folders (id, user_id, name, created_at)
		VALUES ($1, $2, $3, $4)
	`
	_, err := r.pool.Exec(ctx, query, f.ID, f.UserID, f.Name, f.CreatedAt)
	return err
}

func (r *FolderRepositoryPG) GetByID(ctx context.Context, id, userID uuid.UUID) (*entity.Folder, error) {
	var f entity.Folder
	query := `SELECT id, user_id, name, created_at FROM folders WHERE id = $1 AND user_id = $2`
	err := r.pool.QueryRow(ctx, query, id, userID).Scan(&f.ID, &f.UserID, &f.Name, &f.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("folder not found")
		}
		return nil, err
	}
	return &f, nil
}

func (r *FolderRepositoryPG) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Folder, error) {
	query := `SELECT id, user_id, name, created_at FROM folders WHERE user_id = $1 ORDER BY created_at ASC`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []entity.Folder
	for rows.Next() {
		var f entity.Folder
		if err := rows.Scan(&f.ID, &f.UserID, &f.Name, &f.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, f)
	}

	if list == nil {
		list = []entity.Folder{}
	}
	return list, nil
}

func (r *FolderRepositoryPG) Delete(ctx context.Context, id, userID uuid.UUID) error {
	query := `DELETE FROM folders WHERE id = $1 AND user_id = $2`
	_, err := r.pool.Exec(ctx, query, id, userID)
	return err
}
