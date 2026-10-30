package repository

import (
	"context"
	"time"

	"vaultly-be/internal/domain/entity"
)

// LogRepository stores request logs and serves them back to the admin endpoint.
type LogRepository interface {
	// InsertMany writes a batch in one round trip; the sink calls it off the
	// request path.
	InsertMany(ctx context.Context, entries []entity.AppLog) error
	// Recent returns the newest entries first, optionally filtered by level.
	Recent(ctx context.Context, limit int, level string) ([]entity.AppLog, error)
	// DeleteOlderThan prunes entries past the retention window and reports how
	// many rows it removed.
	DeleteOlderThan(ctx context.Context, before time.Time) (int64, error)
}
