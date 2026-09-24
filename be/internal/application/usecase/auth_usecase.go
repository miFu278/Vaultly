package usecase

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
	"vaultly-be/internal/domain/service"
)

type AuthUseCase struct {
	userRepo repository.UserRepository
	hasher   service.PasswordHasher
	tokenSvc service.TokenService
}

func NewAuthUseCase(
	userRepo repository.UserRepository,
	hasher service.PasswordHasher,
	tokenSvc service.TokenService,
) *AuthUseCase {
	return &AuthUseCase{
		userRepo: userRepo,
		hasher:   hasher,
		tokenSvc: tokenSvc,
	}
}

func (uc *AuthUseCase) Register(ctx context.Context, req dto.RegisterRequest) (*dto.AuthResponse, error) {
	email := strings.TrimSpace(strings.ToLower(req.Email))

	hashedPassword, err := uc.hasher.Hash(req.Password)
	if err != nil {
		return nil, err
	}

	user := entity.User{
		Email:        email,
		PasswordHash: hashedPassword,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := uc.userRepo.Create(ctx, &user); err != nil {
		return nil, err
	}

	token, err := uc.tokenSvc.Generate(service.TokenClaims{
		UserID: user.ID,
		Email:  user.Email,
	})
	if err != nil {
		return nil, err
	}

	return &dto.AuthResponse{
		Token: token,
		User:  dto.ToUserDTO(&user),
	}, nil
}

func (uc *AuthUseCase) Login(ctx context.Context, req dto.LoginRequest) (*dto.AuthResponse, error) {
	email := strings.TrimSpace(strings.ToLower(req.Email))

	user, err := uc.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil, err
	}

	if err := uc.hasher.Compare(user.PasswordHash, req.Password); err != nil {
		return nil, err
	}

	token, err := uc.tokenSvc.Generate(service.TokenClaims{
		UserID: user.ID,
		Email:  user.Email,
	})
	if err != nil {
		return nil, err
	}

	return &dto.AuthResponse{
		Token: token,
		User:  dto.ToUserDTO(user),
	}, nil
}

func (uc *AuthUseCase) GetMe(ctx context.Context, userID uuid.UUID) (*dto.UserDTO, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	userDTO := dto.ToUserDTO(user)
	return &userDTO, nil
}
