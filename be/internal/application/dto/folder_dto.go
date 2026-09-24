package dto

import (
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type CreateFolderRequest struct {
	Name string `json:"name" binding:"required,min=1,max=100" example:"Personal Documents"`
}

type FolderDTO struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

func ToFolderDTO(f *entity.Folder) FolderDTO {
	return FolderDTO{
		ID:        f.ID,
		UserID:    f.UserID,
		Name:      f.Name,
		CreatedAt: f.CreatedAt,
	}
}

func ToFolderDTOList(folders []entity.Folder) []FolderDTO {
	list := make([]FolderDTO, len(folders))
	for i, f := range folders {
		list[i] = ToFolderDTO(&f)
	}
	return list
}
