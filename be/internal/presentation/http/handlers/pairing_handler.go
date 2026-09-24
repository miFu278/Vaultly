package handlers

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
)

type PairingStartInput struct {
	Body dto.PairingStartRequest
}

type PairingStartOutput struct {
	Body dto.PairingStartResponse
}

type PairingStatusInput struct {
	Token string `path:"token" doc:"32-byte hex pairing token"`
}

type PairingStatusOutput struct {
	Body dto.PairingStatusResponse
}

type PairingCompleteInput struct {
	Body dto.PairingCompleteRequest
}

func RegisterPairingRoutes(api huma.API, pairingUC *usecase.PairingUseCase) {
	huma.Register(api, huma.Operation{
		OperationID: "startPairing",
		Method:      http.MethodPost,
		Path:        "/pairing/start",
		Summary:     "Start device pairing session for new device",
		Tags:        []string{"Pairing"},
	}, func(ctx context.Context, input *PairingStartInput) (*PairingStartOutput, error) {
		res, err := pairingUC.StartPairing(ctx, input.Body)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &PairingStartOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getPairingStatus",
		Method:      http.MethodGet,
		Path:        "/pairing/{token}",
		Summary:     "Poll pairing status (called by new device)",
		Tags:        []string{"Pairing"},
	}, func(ctx context.Context, input *PairingStatusInput) (*PairingStatusOutput, error) {
		res, err := pairingUC.GetPairingStatus(ctx, input.Token)
		if err != nil {
			return nil, huma.Error404NotFound(err.Error())
		}
		return &PairingStatusOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "completePairing",
		Method:      http.MethodPost,
		Path:        "/pairing/complete",
		Summary:     "Approve pairing and submit wrapped keys for new device",
		Tags:        []string{"Pairing"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *PairingCompleteInput) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}

		if err := pairingUC.CompletePairing(ctx, userID, input.Body); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "Pairing completed and device authorized successfully"
		return resp, nil
	})
}
