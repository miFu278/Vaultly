package usecase

import (
	"context"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain/repository"
)

// StorageUseCase reports how much of the account's quota is in use. Quotas are
// informational for now: uploads are not rejected when they exceed one.
type StorageUseCase struct {
	userRepo repository.UserRepository
	fileRepo repository.FileRepository
}

func NewStorageUseCase(userRepo repository.UserRepository, fileRepo repository.FileRepository) *StorageUseCase {
	return &StorageUseCase{userRepo: userRepo, fileRepo: fileRepo}
}

func (uc *StorageUseCase) Get(ctx context.Context, userID uuid.UUID) (*dto.StorageDTO, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	usage, err := uc.fileRepo.Usage(ctx, userID)
	if err != nil {
		return nil, err
	}

	quota := user.StorageQuotaBytes
	if quota <= 0 {
		quota = dto.DefaultStorageQuotaBytes
	}

	return &dto.StorageDTO{
		UsedBytes:   usage.TotalBytes,
		QuotaBytes:  quota,
		PhotoBytes:  usage.PhotoBytes,
		VideoBytes:  usage.VideoBytes,
		FileCount:   usage.FileCount,
		UsedPercent: usedPercent(usage.TotalBytes, quota),
	}, nil
}

// usedPercent is capped at 100 so a database that already holds more than the
// quota cannot draw a gauge past its own end.
func usedPercent(used, quota int64) float64 {
	if quota <= 0 || used <= 0 {
		return 0
	}
	percent := float64(used) / float64(quota) * 100
	if percent > 100 {
		return 100
	}
	return percent
}
