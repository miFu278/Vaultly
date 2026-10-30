package usecase

import (
	"context"

	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

// LogUseCase reads the request log for the admin endpoint.
type LogUseCase struct {
	repo repository.LogRepository
}

func NewLogUseCase(repo repository.LogRepository) *LogUseCase {
	return &LogUseCase{repo: repo}
}

func (uc *LogUseCase) Recent(ctx context.Context, limit int, level string) ([]entity.AppLog, error) {
	switch level {
	case "info", "warn", "error":
	case "":
	default:
		level = "" // unknown filters read as "all" instead of returning nothing
	}
	return uc.repo.Recent(ctx, limit, level)
}
