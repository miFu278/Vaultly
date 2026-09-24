package handlers

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
)

type RegisterDeviceInput struct {
	Body dto.RegisterDeviceRequest
}

type DeviceOutput struct {
	Body dto.DeviceDTO
}

type ListDevicesOutput struct {
	Body []dto.DeviceDTO
}

type RevokeDeviceInput struct {
	ID string `path:"id" doc:"Device UUID to revoke"`
}

func RegisterDeviceRoutes(api huma.API, deviceUC *usecase.DeviceUseCase) {
	huma.Register(api, huma.Operation{
		OperationID: "registerDevice",
		Method:      http.MethodPost,
		Path:        "/devices/register",
		Summary:     "Register a new device public key",
		Tags:        []string{"Devices"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *RegisterDeviceInput) (*DeviceOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		dev, err := deviceUC.RegisterDevice(ctx, userID, input.Body)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		return &DeviceOutput{Body: *dev}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listDevices",
		Method:      http.MethodGet,
		Path:        "/devices",
		Summary:     "List all active authorized devices",
		Tags:        []string{"Devices"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*ListDevicesOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		devices, err := deviceUC.ListDevices(ctx, userID)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &ListDevicesOutput{Body: devices}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "revokeDevice",
		Method:      http.MethodPost,
		Path:        "/devices/{id}/revoke",
		Summary:     "Revoke an authorized device",
		Tags:        []string{"Devices"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *RevokeDeviceInput) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		deviceID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid device ID format")
		}

		if err := deviceUC.RevokeDevice(ctx, userID, deviceID); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "Device revoked successfully"
		return resp, nil
	})
}
