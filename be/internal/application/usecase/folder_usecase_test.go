package usecase_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain/entity"
)

type MockFolderRepo struct {
	folders map[uuid.UUID]*entity.Folder
}

func NewMockFolderRepo() *MockFolderRepo {
	return &MockFolderRepo{folders: make(map[uuid.UUID]*entity.Folder)}
}

func (m *MockFolderRepo) Create(ctx context.Context, f *entity.Folder) error {
	m.folders[f.ID] = f
	return nil
}

func (m *MockFolderRepo) GetByID(ctx context.Context, id, userID uuid.UUID) (*entity.Folder, error) {
	if f, ok := m.folders[id]; ok && f.UserID == userID {
		return f, nil
	}
	return nil, errors.New("folder not found")
}

func (m *MockFolderRepo) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Folder, error) {
	var list []entity.Folder
	for _, f := range m.folders {
		if f.UserID == userID {
			list = append(list, *f)
		}
	}
	return list, nil
}

func (m *MockFolderRepo) Delete(ctx context.Context, id, userID uuid.UUID) error {
	if f, ok := m.folders[id]; !ok || f.UserID != userID {
		return errors.New("folder not found")
	}
	delete(m.folders, id)
	return nil
}

func TestDeleteFolder(t *testing.T) {
	ctx := context.Background()
	owner := uuid.New()
	stranger := uuid.New()
	repo := NewMockFolderRepo()
	uc := usecase.NewFolderUseCase(repo)

	created, err := uc.CreateFolder(ctx, owner, dto.CreateFolderRequest{Name: "Tài chính"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	// Another user must not be able to delete the folder.
	if err := uc.DeleteFolder(ctx, stranger, created.ID); err == nil {
		t.Fatal("expected cross-user delete to fail, got nil")
	}
	if _, ok := repo.folders[created.ID]; !ok {
		t.Fatal("folder was deleted by a non-owner")
	}

	if err := uc.DeleteFolder(ctx, owner, created.ID); err != nil {
		t.Fatalf("owner delete: %v", err)
	}
	if _, ok := repo.folders[created.ID]; ok {
		t.Fatal("folder still present after delete")
	}
}
