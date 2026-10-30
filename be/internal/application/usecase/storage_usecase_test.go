package usecase_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain/entity"
)

// The storage gauge is only honest if the numbers come from the file rows, so
// this pins the breakdown, the deleted-file exclusion and the percent maths.
func TestStorageUsage_ReportsQuotaAndBreakdown(t *testing.T) {
	ctx := context.Background()
	users := newMemoryUserRepo()
	user := &entity.User{Email: "user@example.com", StorageQuotaBytes: 1000}
	if err := users.Create(ctx, user); err != nil {
		t.Fatalf("Create user failed: %v", err)
	}

	files := NewMockFileRepo()
	files.files[uuid.New()] = &entity.File{
		UserID: user.ID, Size: 400, ContentType: "image/jpeg", Status: entity.FileStatusReady,
	}
	files.files[uuid.New()] = &entity.File{
		UserID: user.ID, Size: 100, ContentType: "video/mp4", Status: entity.FileStatusReady,
	}
	files.files[uuid.New()] = &entity.File{
		UserID: user.ID, Size: 900, ContentType: "image/png", Status: entity.FileStatusDeleted,
	}
	// Another account's file must not be counted.
	files.files[uuid.New()] = &entity.File{
		UserID: uuid.New(), Size: 5000, ContentType: "image/png", Status: entity.FileStatusReady,
	}

	storageUC := usecase.NewStorageUseCase(users, files)
	got, err := storageUC.Get(ctx, user.ID)
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}

	if got.UsedBytes != 500 || got.PhotoBytes != 400 || got.VideoBytes != 100 || got.FileCount != 2 {
		t.Fatalf("usage = %+v, want 500 total (400 photo, 100 video) over 2 files", got)
	}
	if got.QuotaBytes != 1000 {
		t.Fatalf("quota = %d, want the account's 1000", got.QuotaBytes)
	}
	if got.UsedPercent != 50 {
		t.Fatalf("percent = %v, want 50", got.UsedPercent)
	}
}

func TestStorageUsage_FallsBackToDefaultQuota(t *testing.T) {
	ctx := context.Background()
	users := newMemoryUserRepo()
	user := &entity.User{Email: "user@example.com"} // no quota on the row
	if err := users.Create(ctx, user); err != nil {
		t.Fatalf("Create user failed: %v", err)
	}

	storageUC := usecase.NewStorageUseCase(users, NewMockFileRepo())
	got, err := storageUC.Get(ctx, user.ID)
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}
	if got.QuotaBytes != dto.DefaultStorageQuotaBytes {
		t.Fatalf("quota = %d, want the default %d", got.QuotaBytes, dto.DefaultStorageQuotaBytes)
	}
	if got.UsedPercent != 0 {
		t.Fatalf("percent = %v, want 0 for an empty vault", got.UsedPercent)
	}
}

// An account already over its quota must not draw a gauge past 100%.
func TestStorageUsage_ClampsPercentAtFull(t *testing.T) {
	ctx := context.Background()
	users := newMemoryUserRepo()
	user := &entity.User{Email: "user@example.com", StorageQuotaBytes: 10}
	if err := users.Create(ctx, user); err != nil {
		t.Fatalf("Create user failed: %v", err)
	}

	files := NewMockFileRepo()
	files.files[uuid.New()] = &entity.File{
		UserID: user.ID, Size: 25, ContentType: "image/jpeg", Status: entity.FileStatusReady,
	}

	storageUC := usecase.NewStorageUseCase(users, files)
	got, err := storageUC.Get(ctx, user.ID)
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}
	if got.UsedPercent != 100 {
		t.Fatalf("percent = %v, want it clamped to 100", got.UsedPercent)
	}
	if got.UsedBytes != 25 {
		t.Fatalf("used = %d, want the real 25 so the UI can show it is over quota", got.UsedBytes)
	}
}
