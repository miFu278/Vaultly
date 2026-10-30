package handlers

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
)

type StorageOutput struct {
	Body dto.StorageDTO
}

func RegisterStorageRoutes(api huma.API, storageUC *usecase.StorageUseCase) {
	huma.Register(api, huma.Operation{
		OperationID: "getStorageUsage",
		Method:      http.MethodGet,
		Path:        "/storage",
		Summary:     "Vault usage and quota for the current account",
		Tags:        []string{"Storage"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*StorageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		res, err := storageUC.Get(ctx, userID)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &StorageOutput{Body: *res}, nil
	})
}
