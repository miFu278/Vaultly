package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
)

type HealthOutput struct {
	Body struct {
		Status    string `json:"status" example:"healthy"`
		Service   string `json:"service" example:"vaultly-backend"`
		Timestamp string `json:"timestamp"`
	}
}

func RegisterSystemRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "healthCheck",
		Method:      http.MethodGet,
		Path:        "/health",
		Summary:     "Health check",
		Description: "Check if the Vaultly backend service is healthy",
		Tags:        []string{"System"},
	}, func(ctx context.Context, input *struct{}) (*HealthOutput, error) {
		resp := &HealthOutput{}
		resp.Body.Status = "healthy"
		resp.Body.Service = "vaultly-backend"
		resp.Body.Timestamp = time.Now().Format(time.RFC3339)
		return resp, nil
	})
}
