package handlers

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
)

type CreateFolderInput struct {
	Body dto.CreateFolderRequest
}

type CreateFolderOutput struct {
	Body dto.FolderDTO
}

type ListFoldersOutput struct {
	Body []dto.FolderDTO
}

type ListFolderFilesInput struct {
	ID     string `path:"id" doc:"Folder UUID to list files from"`
	Cursor string `query:"cursor" doc:"RFC3339 timestamp cursor from previous response"`
	Limit  int    `query:"limit" default:"30" doc:"Number of items per page (default: 30, max: 100)"`
}

type ListFolderFilesOutput struct {
	Body dto.PaginatedFilesResponse
}

type DeleteFolderInput struct {
	ID string `path:"id" doc:"Folder UUID to delete"`
}

func RegisterFolderRoutes(api huma.API, folderUC *usecase.FolderUseCase, fileUC *usecase.FileUseCase) {
	huma.Register(api, huma.Operation{
		OperationID: "createFolder",
		Method:      http.MethodPost,
		Path:        "/folders",
		Summary:     "Create a new folder for photos (Knox Secure Folder style)",
		Tags:        []string{"Folders"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *CreateFolderInput) (*CreateFolderOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		res, err := folderUC.CreateFolder(ctx, userID, input.Body)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		return &CreateFolderOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listFolders",
		Method:      http.MethodGet,
		Path:        "/folders",
		Summary:     "List all user folders",
		Tags:        []string{"Folders"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*ListFoldersOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		folders, err := folderUC.ListFolders(ctx, userID)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &ListFoldersOutput{Body: folders}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteFolder",
		Method:      http.MethodDelete,
		Path:        "/folders/{id}",
		Summary:     "Delete a folder (files inside are moved back to the root vault)",
		Tags:        []string{"Folders"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *DeleteFolderInput) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		folderID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid folder ID format")
		}

		if err := folderUC.DeleteFolder(ctx, userID, folderID); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "Folder deleted successfully"
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listFolderFiles",
		Method:      http.MethodGet,
		Path:        "/folders/{id}/files",
		Summary:     "List files inside a folder with cursor-based pagination",
		Description: "Fast, single-query SQL pagination (20-30 items/page). Returns thumbnails and next_cursor.",
		Tags:        []string{"Folders"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *ListFolderFilesInput) (*ListFolderFilesOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}

		var folderID *uuid.UUID
		if input.ID != "" && input.ID != "root" {
			parsed, err := uuid.Parse(input.ID)
			if err != nil {
				return nil, huma.Error400BadRequest("Invalid folder ID format")
			}
			folderID = &parsed
		}

		res, err := fileUC.ListFilesByFolder(ctx, userID, folderID, input.Cursor, input.Limit)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}

		return &ListFolderFilesOutput{Body: *res}, nil
	})
}
