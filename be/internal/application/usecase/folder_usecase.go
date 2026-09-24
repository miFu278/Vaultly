package usecase

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type FolderUseCase struct {
	folderRepo repository.FolderRepository
}

func NewFolderUseCase(folderRepo repository.FolderRepository) *FolderUseCase {
	return &FolderUseCase{folderRepo: folderRepo}
}

func (uc *FolderUseCase) CreateFolder(ctx context.Context, userID uuid.UUID, req dto.CreateFolderRequest) (*dto.FolderDTO, error) {
	name := strings.TrimSpace(req.Name)
	folder := entity.Folder{
		ID:        uuid.New(),
		UserID:    userID,
		Name:      name,
		CreatedAt: time.Now(),
	}

	if err := uc.folderRepo.Create(ctx, &folder); err != nil {
		return nil, err
	}

	res := dto.ToFolderDTO(&folder)
	return &res, nil
}

func (uc *FolderUseCase) ListFolders(ctx context.Context, userID uuid.UUID) ([]dto.FolderDTO, error) {
	folders, err := uc.folderRepo.ListByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return dto.ToFolderDTOList(folders), nil
}
