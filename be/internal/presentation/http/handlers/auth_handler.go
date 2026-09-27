package handlers

import (
	"context"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
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

type SetPINInput struct {
	Body dto.SetPINRequest
}

type VerifyPINInput struct {
	Body dto.VerifyPINRequest
}

type VerifyPINOutput struct {
	Body dto.VerifyPINResponse
}

type MeUserOutput struct {
	Body dto.UserDTO
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
		Summary:     "Get current authenticated user profile (includes has_pin)",
		Tags:        []string{"Auth"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*MeUserOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		userDTO, err := authUC.GetMe(ctx, userID)
		if err != nil {
			return nil, huma.Error404NotFound(err.Error())
		}
		return &MeUserOutput{Body: *userDTO}, nil
	})

	// PIN management endpoints
	huma.Register(api, huma.Operation{
		OperationID: "setPIN",
		Method:      http.MethodPost,
		Path:        "/auth/pin/set",
		Summary:     "Set or update 6-digit PIN (synced across all devices)",
		Tags:        []string{"Auth"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *SetPINInput) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		if err := authUC.SetPIN(ctx, userID, input.Body.PIN); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		resp := &MessageOutput{}
		resp.Body.Message = "PIN set successfully"
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "verifyPIN",
		Method:      http.MethodPost,
		Path:        "/auth/pin/verify",
		Summary:     "Verify 6-digit PIN",
		Tags:        []string{"Auth"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *VerifyPINInput) (*VerifyPINOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		valid, err := authUC.VerifyPIN(ctx, userID, input.Body.PIN)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		return &VerifyPINOutput{Body: dto.VerifyPINResponse{Valid: valid}}, nil
	})
}

