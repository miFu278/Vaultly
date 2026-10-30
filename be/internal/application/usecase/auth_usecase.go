package usecase

import (
	"context"
	"errors"
	"net/mail"
	"strings"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
	"vaultly-be/internal/domain/service"
)

// minPasswordLength is the shortest password /auth/register accepts.
const minPasswordLength = 8

// normalizeEmail lower-cases an address and rejects anything that is not a
// single bare mailbox. It lives here because the HTTP layer's struct tags are
// not enforced: the API is served by Huma, not by Gin's validator.
func normalizeEmail(raw string) (string, error) {
	email := strings.ToLower(strings.TrimSpace(raw))
	addr, err := mail.ParseAddress(email)
	if err != nil || addr.Address != email {
		return "", errors.New("invalid email address")
	}
	return email, nil
}

// validatePin requires exactly six digits, not just six characters.
func validatePin(pin string) (string, error) {
	pin = strings.TrimSpace(pin)
	if len(pin) != 6 || strings.Trim(pin, "0123456789") != "" {
		return "", errors.New("PIN must be exactly 6 digits")
	}
	return pin, nil
}

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
	email, err := normalizeEmail(req.Email)
	if err != nil {
		return nil, err
	}
	if len(req.Password) < minPasswordLength {
		return nil, errors.New("password must be at least 8 characters")
	}

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
	email, err := normalizeEmail(req.Email)
	if err != nil {
		return nil, err
	}
	if req.Password == "" {
		return nil, errors.New("password is required")
	}

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

func (uc *AuthUseCase) SetPIN(ctx context.Context, userID uuid.UUID, pin string) error {
	pin, err := validatePin(pin)
	if err != nil {
		return err
	}
	hashedPIN, err := uc.hasher.Hash(pin)
	if err != nil {
		return err
	}
	return uc.userRepo.UpdatePIN(ctx, userID, hashedPIN)
}

func (uc *AuthUseCase) VerifyPIN(ctx context.Context, userID uuid.UUID, pin string) (bool, error) {
	pin, err := validatePin(pin)
	if err != nil {
		return false, err
	}
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return false, err
	}
	if user.PINHash == "" {
		return false, errors.New("no PIN set for this user")
	}
	if err := uc.hasher.Compare(user.PINHash, pin); err != nil {
		return false, nil
	}
	return true, nil
}
