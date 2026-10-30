package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type FileRepositoryPG struct {
	pool *pgxpool.Pool
}

func NewFileRepository(pool *pgxpool.Pool) repository.FileRepository {
	return &FileRepositoryPG{pool: pool}
}

func (r *FileRepositoryPG) Create(ctx context.Context, file *entity.File) error {
	query := `
		INSERT INTO files (id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	_, err := r.pool.Exec(ctx, query, file.ID, file.UserID, file.FolderID, file.R2ObjectKey, file.R2ThumbnailKey, file.Size, file.ContentType, file.Nonce, file.Status, file.CreatedAt, file.UpdatedAt)
	return err
}

func (r *FileRepositoryPG) GetByID(ctx context.Context, id, userID uuid.UUID) (*entity.File, error) {
	var f entity.File
	query := `
		SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
		FROM files
		WHERE id = $1 AND user_id = $2
	`
	err := r.pool.QueryRow(ctx, query, id, userID).
		Scan(&f.ID, &f.UserID, &f.FolderID, &f.R2ObjectKey, &f.R2ThumbnailKey, &f.Size, &f.ContentType, &f.Nonce, &f.Status, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrFileNotFound
		}
		return nil, err
	}
	return &f, nil
}

func (r *FileRepositoryPG) GetReadyByID(ctx context.Context, id, userID uuid.UUID) (*entity.File, error) {
	var f entity.File
	query := `
		SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
		FROM files
		WHERE id = $1 AND user_id = $2 AND status = 'ready'
	`
	err := r.pool.QueryRow(ctx, query, id, userID).
		Scan(&f.ID, &f.UserID, &f.FolderID, &f.R2ObjectKey, &f.R2ThumbnailKey, &f.Size, &f.ContentType, &f.Nonce, &f.Status, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrFileNotFound
		}
		return nil, err
	}
	return &f, nil
}

func (r *FileRepositoryPG) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.File, error) {
	query := `
		SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
		FROM files
		WHERE user_id = $1 AND status = 'ready'
		ORDER BY created_at DESC
	`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []entity.File
	for rows.Next() {
		var f entity.File
		if err := rows.Scan(&f.ID, &f.UserID, &f.FolderID, &f.R2ObjectKey, &f.R2ThumbnailKey, &f.Size, &f.ContentType, &f.Nonce, &f.Status, &f.CreatedAt, &f.UpdatedAt); err != nil {
			return nil, err
		}
		files = append(files, f)
	}

	if files == nil {
		files = []entity.File{}
	}

	return files, nil
}

func (r *FileRepositoryPG) ListByFolder(
	ctx context.Context,
	userID uuid.UUID,
	folderID *uuid.UUID,
	cursor *time.Time,
	limit int,
) (files []entity.File, nextCursor *time.Time, hasMore bool, err error) {
	// Query limit + 1 to detect hasMore
	queryLimit := limit + 1

	var rows pgx.Rows
	if folderID != nil {
		if cursor != nil {
			q := `
				SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
				FROM files
				WHERE user_id = $1 AND folder_id = $2 AND status = 'ready' AND created_at < $3
				ORDER BY created_at DESC
				LIMIT $4
			`
			rows, err = r.pool.Query(ctx, q, userID, *folderID, *cursor, queryLimit)
		} else {
			q := `
				SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
				FROM files
				WHERE user_id = $1 AND folder_id = $2 AND status = 'ready'
				ORDER BY created_at DESC
				LIMIT $3
			`
			rows, err = r.pool.Query(ctx, q, userID, *folderID, queryLimit)
		}
	} else {
		// Root or all files for user
		if cursor != nil {
			q := `
				SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
				FROM files
				WHERE user_id = $1 AND status = 'ready' AND created_at < $2
				ORDER BY created_at DESC
				LIMIT $3
			`
			rows, err = r.pool.Query(ctx, q, userID, *cursor, queryLimit)
		} else {
			q := `
				SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
				FROM files
				WHERE user_id = $1 AND status = 'ready'
				ORDER BY created_at DESC
				LIMIT $2
			`
			rows, err = r.pool.Query(ctx, q, userID, queryLimit)
		}
	}

	if err != nil {
		return nil, nil, false, err
	}
	defer rows.Close()

	for rows.Next() {
		var f entity.File
		if err := rows.Scan(&f.ID, &f.UserID, &f.FolderID, &f.R2ObjectKey, &f.R2ThumbnailKey, &f.Size, &f.ContentType, &f.Nonce, &f.Status, &f.CreatedAt, &f.UpdatedAt); err != nil {
			return nil, nil, false, err
		}
		files = append(files, f)
	}

	if len(files) > limit {
		hasMore = true
		files = files[:limit]
		lastItem := files[len(files)-1]
		nextCursor = &lastItem.CreatedAt
	}

	if files == nil {
		files = []entity.File{}
	}

	return files, nextCursor, hasMore, nil
}

func (r *FileRepositoryPG) UpdateStatus(ctx context.Context, id uuid.UUID, status entity.FileStatus) error {
	query := `UPDATE files SET status = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.pool.Exec(ctx, query, status, id)
	return err
}

// MarkDeleted hides a file and reports the objects it uses. The row is kept until
// the caller has removed the ciphertext, so a storage failure leaves something to
// retry instead of an object nothing points at.
func (r *FileRepositoryPG) MarkDeleted(ctx context.Context, id, userID uuid.UUID) (string, string, bool, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return "", "", false, err
	}
	defer tx.Rollback(ctx)

	var objectKey, thumbKey string
	query := `SELECT r2_object_key, r2_thumbnail_key FROM files WHERE id = $1 AND user_id = $2 FOR UPDATE`
	err = tx.QueryRow(ctx, query, id, userID).Scan(&objectKey, &thumbKey)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", "", false, domain.ErrFileNotFound
		}
		return "", "", false, err
	}

	if _, err = tx.Exec(ctx, `UPDATE files SET status = 'deleted', updated_at = NOW() WHERE id = $1`, id); err != nil {
		return "", "", false, err
	}

	// A copy of this file shares both keys; the ciphertext may only be deleted
	// after the last live record that points at it is gone.
	sharedQuery := `
		SELECT EXISTS (
			SELECT 1 FROM files
			WHERE id <> $1 AND status <> 'deleted'
			  AND (r2_object_key = $2 OR ($3 <> '' AND r2_thumbnail_key = $3))
		)
	`
	var shared bool
	if err = tx.QueryRow(ctx, sharedQuery, id, objectKey, thumbKey).Scan(&shared); err != nil {
		return "", "", false, err
	}

	if err = tx.Commit(ctx); err != nil {
		return "", "", false, err
	}
	return objectKey, thumbKey, shared, nil
}

// Purge drops the metadata row of a file that MarkDeleted already hid.
func (r *FileRepositoryPG) Purge(ctx context.Context, id, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM files WHERE id = $1 AND user_id = $2`, id, userID)
	return err
}

// Usage sums the size of the user's live files in one query, split by media
// kind so the dashboard can show a breakdown without a second round trip.
func (r *FileRepositoryPG) Usage(ctx context.Context, userID uuid.UUID) (entity.FileUsage, error) {
	query := `
		SELECT
			COALESCE(SUM(size), 0),
			COUNT(*),
			COALESCE(SUM(size) FILTER (WHERE content_type LIKE 'image/%'), 0),
			COALESCE(SUM(size) FILTER (WHERE content_type LIKE 'video/%'), 0)
		FROM files
		WHERE user_id = $1 AND status <> 'deleted'
	`
	var usage entity.FileUsage
	err := r.pool.QueryRow(ctx, query, userID).
		Scan(&usage.TotalBytes, &usage.FileCount, &usage.PhotoBytes, &usage.VideoBytes)
	if err != nil {
		return entity.FileUsage{}, err
	}
	return usage, nil
}

func (r *FileRepositoryPG) SaveFileKeys(ctx context.Context, fileID uuid.UUID, keys []entity.FileKey) error {
	keyInsertQuery := `
		INSERT INTO file_keys (file_id, device_id, wrapped_key, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (file_id, device_id) DO UPDATE SET wrapped_key = EXCLUDED.wrapped_key
	`
	for _, wk := range keys {
		_, err := r.pool.Exec(ctx, keyInsertQuery, fileID, wk.DeviceID, wk.WrappedKey)
		if err != nil {
			return fmt.Errorf("failed to insert wrapped key for device %s: %w", wk.DeviceID, err)
		}
	}
	return nil
}

func (r *FileRepositoryPG) GetFileKey(ctx context.Context, fileID, deviceID uuid.UUID) (*entity.FileKey, error) {
	var fk entity.FileKey
	fk.FileID = fileID
	fk.DeviceID = deviceID
	query := `SELECT wrapped_key, created_at FROM file_keys WHERE file_id = $1 AND device_id = $2`
	err := r.pool.QueryRow(ctx, query, fileID, deviceID).Scan(&fk.WrappedKey, &fk.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrDeviceUnauthorized
		}
		return nil, err
	}
	return &fk, nil
}

func (r *FileRepositoryPG) GetFileKeysForDevice(ctx context.Context, deviceID uuid.UUID) ([]entity.FileKey, error) {
	query := `SELECT file_id, device_id, wrapped_key, created_at FROM file_keys WHERE device_id = $1`
	rows, err := r.pool.Query(ctx, query, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var keys []entity.FileKey
	for rows.Next() {
		var fk entity.FileKey
		if err := rows.Scan(&fk.FileID, &fk.DeviceID, &fk.WrappedKey, &fk.CreatedAt); err != nil {
			return nil, err
		}
		keys = append(keys, fk)
	}
	return keys, nil
}

func (r *FileRepositoryPG) CompleteUploadTx(ctx context.Context, userID, fileID uuid.UUID, keys []entity.FileKey) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Verify file belongs to user and is pending
	var status string
	checkQuery := `SELECT status FROM files WHERE id = $1 AND user_id = $2 FOR UPDATE`
	err = tx.QueryRow(ctx, checkQuery, fileID, userID).Scan(&status)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrFileNotFound
		}
		return err
	}

	if status != string(entity.FileStatusPending) {
		return domain.ErrFileNotPending
	}

	// Insert wrapped keys for each authorized device
	keyInsertQuery := `
		INSERT INTO file_keys (file_id, device_id, wrapped_key, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (file_id, device_id) DO UPDATE SET wrapped_key = EXCLUDED.wrapped_key
	`
	for _, wk := range keys {
		_, err = tx.Exec(ctx, keyInsertQuery, fileID, wk.DeviceID, wk.WrappedKey)
		if err != nil {
			return fmt.Errorf("failed to insert wrapped key for device %s: %w", wk.DeviceID, err)
		}
	}

	// Update file status to ready
	updateQuery := `UPDATE files SET status = 'ready', updated_at = NOW() WHERE id = $1`
	_, err = tx.Exec(ctx, updateQuery, fileID)
	if err != nil {
		return fmt.Errorf("failed to mark file ready: %w", err)
	}

	return tx.Commit(ctx)
}

func (r *FileRepositoryPG) UpdateFolderID(ctx context.Context, id, userID uuid.UUID, folderID *uuid.UUID) error {
	query := `UPDATE files SET folder_id = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`
	tag, err := r.pool.Exec(ctx, query, folderID, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrFileNotFound
	}
	return nil
}

func (r *FileRepositoryPG) CopyFile(ctx context.Context, id, userID uuid.UUID, targetFolderID *uuid.UUID) (*entity.File, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var orig entity.File
	query := `
		SELECT id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at
		FROM files
		WHERE id = $1 AND user_id = $2
	`
	err = tx.QueryRow(ctx, query, id, userID).
		Scan(&orig.ID, &orig.UserID, &orig.FolderID, &orig.R2ObjectKey, &orig.R2ThumbnailKey, &orig.Size, &orig.ContentType, &orig.Nonce, &orig.Status, &orig.CreatedAt, &orig.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrFileNotFound
		}
		return nil, err
	}

	newFileID := uuid.New()
	now := time.Now()
	insertQuery := `
		INSERT INTO files (id, user_id, folder_id, r2_object_key, r2_thumbnail_key, size, content_type, nonce, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`
	_, err = tx.Exec(ctx, insertQuery, newFileID, userID, targetFolderID, orig.R2ObjectKey, orig.R2ThumbnailKey, orig.Size, orig.ContentType, orig.Nonce, orig.Status, now, now)
	if err != nil {
		return nil, err
	}

	copyKeysQuery := `
		INSERT INTO file_keys (file_id, device_id, wrapped_key, created_at)
		SELECT $1, device_id, wrapped_key, NOW()
		FROM file_keys
		WHERE file_id = $2
	`
	_, _ = tx.Exec(ctx, copyKeysQuery, newFileID, id)

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	newFile := orig
	newFile.ID = newFileID
	newFile.FolderID = targetFolderID
	newFile.CreatedAt = now
	newFile.UpdatedAt = now
	return &newFile, nil
}
