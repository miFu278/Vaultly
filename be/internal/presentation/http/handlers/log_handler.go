package handlers

import (
	"context"
	"crypto/subtle"
	"net/http"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain/entity"
)

type LogsInput struct {
	Authorization string `header:"Authorization" doc:"Bearer <ADMIN_TOKEN>"`
	Limit         int    `query:"limit" default:"200" doc:"How many entries, newest first"`
	Level         string `query:"level" enum:"info,warn,error," doc:"Filter by level"`
}

type LogsOutput struct {
	Body struct {
		Logs []entity.AppLog `json:"logs"`
	}
}

// RegisterLogRoutes exposes the stored request log. It is only registered when
// ADMIN_TOKEN is set, so a deployment that forgets the token simply has no
// endpoint rather than an open one.
func RegisterLogRoutes(api huma.API, logUC *usecase.LogUseCase, adminToken string) {
	token := strings.TrimSpace(adminToken)
	if token == "" {
		return
	}

	huma.Register(api, huma.Operation{
		OperationID: "recentLogs",
		Method:      http.MethodGet,
		Path:        "/admin/logs",
		Summary:     "Recent request log",
		Description: "Newest first. Requires the ADMIN_TOKEN from the deployment environment, not a user session.",
		Tags:        []string{"Admin"},
	}, func(ctx context.Context, input *LogsInput) (*LogsOutput, error) {
		provided := strings.TrimSpace(strings.TrimPrefix(input.Authorization, "Bearer "))
		if subtle.ConstantTimeCompare([]byte(provided), []byte(token)) != 1 {
			return nil, huma.Error401Unauthorized("admin token required")
		}

		logs, err := logUC.Recent(ctx, input.Limit, input.Level)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}

		out := &LogsOutput{}
		out.Body.Logs = logs
		return out, nil
	})
}
