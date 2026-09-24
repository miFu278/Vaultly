package handlers

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
)

type AuthRegisterInput struct {
	Body dto.RegisterRequest
}

type AuthLoginInput struct {
	Body dto.LoginRequest
}

type AuthOutput struct {
	Body dto.AuthResponse
}

type MeOutput struct {
	Body struct {
		UserID uuid.UUID `json:"user_id"`
		Email  string    `json:"email"`
	}
}

func RegisterAuthRoutes(api huma.API, authUC *usecase.AuthUseCase) {
	huma.Register(api, huma.Operation{
		OperationID: "registerUser",
		Method:      http.MethodPost,
		Path:        "/auth/register",
		Summary:     "Register a new user account",
		Tags:        []string{"Auth"},
	}, func(ctx context.Context, input *AuthRegisterInput) (*AuthOutput, error) {
		res, err := authUC.Register(ctx, input.Body)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		return &AuthOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "loginUser",
		Method:      http.MethodPost,
		Path:        "/auth/login",
		Summary:     "Login with email & password",
		Tags:        []string{"Auth"},
	}, func(ctx context.Context, input *AuthLoginInput) (*AuthOutput, error) {
		res, err := authUC.Login(ctx, input.Body)
		if err != nil {
			return nil, huma.Error401Unauthorized(err.Error())
		}
		return &AuthOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getCurrentUser",
		Method:      http.MethodGet,
		Path:        "/auth/me",
		Summary:     "Get current authenticated user profile",
		Tags:        []string{"Auth"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*MeOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		email, _ := ctx.Value(EmailKey).(string)

		resp := &MeOutput{}
		resp.Body.UserID = userID
		resp.Body.Email = email
		return resp, nil
	})
}
