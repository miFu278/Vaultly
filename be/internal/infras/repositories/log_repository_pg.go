package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type LogRepositoryPG struct {
	pool *pgxpool.Pool
}

func NewLogRepository(pool *pgxpool.Pool) repository.LogRepository {
	return &LogRepositoryPG{pool: pool}
}

func (r *LogRepositoryPG) InsertMany(ctx context.Context, entries []entity.AppLog) error {
	if len(entries) == 0 {
		return nil
	}

	batch := &pgx.Batch{}
	const query = `
		INSERT INTO app_logs (level, method, path, status, duration_ms, user_id, message)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	for _, e := range entries {
		batch.Queue(query, e.Level, e.Method, e.Path, e.Status, e.DurationMS, e.UserID, e.Message)
	}

	results := r.pool.SendBatch(ctx, batch)
	defer results.Close()
	for range entries {
		if _, err := results.Exec(); err != nil {
			return fmt.Errorf("failed to insert log batch: %w", err)
		}
	}
	return nil
}

func (r *LogRepositoryPG) Recent(ctx context.Context, limit int, level string) ([]entity.AppLog, error) {
	if limit <= 0 || limit > 1000 {
		limit = 200
	}

	query := `
		SELECT id, created_at, level, method, path, status, duration_ms, user_id, message
		FROM app_logs
		WHERE ($1 = '' OR level = $1)
		ORDER BY created_at DESC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, level, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	logs := make([]entity.AppLog, 0, limit)
	for rows.Next() {
		var entry entity.AppLog
		var userID *uuid.UUID
		if err := rows.Scan(&entry.ID, &entry.CreatedAt, &entry.Level, &entry.Method,
			&entry.Path, &entry.Status, &entry.DurationMS, &userID, &entry.Message); err != nil {
			return nil, err
		}
		entry.UserID = userID
		logs = append(logs, entry)
	}
	return logs, rows.Err()
}

func (r *LogRepositoryPG) DeleteOlderThan(ctx context.Context, before time.Time) (int64, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM app_logs WHERE created_at < $1`, before)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
