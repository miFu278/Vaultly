package usecase_test

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/infras/crypto"
)

// memoryUserRepo is the smallest user store the auth use case needs.
type memoryUserRepo struct {
	byEmail map[string]*entity.User
	byID    map[uuid.UUID]*entity.User
}

func newMemoryUserRepo() *memoryUserRepo {
	return &memoryUserRepo{byEmail: map[string]*entity.User{}, byID: map[uuid.UUID]*entity.User{}}
}

func (m *memoryUserRepo) Create(ctx context.Context, u *entity.User) error {
	if _, exists := m.byEmail[u.Email]; exists {
		return domain.ErrEmailAlreadyExists
	}
	u.ID = uuid.New()
	m.byEmail[u.Email] = u
	m.byID[u.ID] = u
	return nil
}

func (m *memoryUserRepo) GetByID(ctx context.Context, id uuid.UUID) (*entity.User, error) {
	if u, ok := m.byID[id]; ok {
		return u, nil
	}
	return nil, domain.ErrUserNotFound
}

func (m *memoryUserRepo) GetByEmail(ctx context.Context, email string) (*entity.User, error) {
	if u, ok := m.byEmail[email]; ok {
		return u, nil
	}
	return nil, domain.ErrUserNotFound
}

func (m *memoryUserRepo) UpdatePIN(ctx context.Context, id uuid.UUID, pinHash string) error {
	if u, ok := m.byID[id]; ok {
		u.PINHash = pinHash
	}
	return nil
}

func newAuthUseCase() (*usecase.AuthUseCase, *memoryUserRepo) {
	repo := newMemoryUserRepo()
	return usecase.NewAuthUseCase(repo, crypto.NewBcryptHasher(), crypto.NewJWTTokenService("test-secret", 1)), repo
}

// The API used to accept anything here: the DTOs carry Gin binding tags, but the
// routes are served by Huma, which never reads them.
func TestRegister_RejectsInvalidInput(t *testing.T) {
	authUC, repo := newAuthUseCase()

	if _, err := authUC.Register(context.Background(), dto.RegisterRequest{Email: "not-an-email", Password: "strongpassword"}); err == nil {
		t.Fatal("an invalid email must be rejected")
	}
	if _, err := authUC.Register(context.Background(), dto.RegisterRequest{Email: "user@example.com", Password: "x"}); err == nil {
		t.Fatal("a one-character password must be rejected")
	}
	if len(repo.byEmail) != 0 {
		t.Fatalf("persisted %d users for invalid input", len(repo.byEmail))
	}
}

func TestRegister_NormalizesEmail(t *testing.T) {
	authUC, repo := newAuthUseCase()

	res, err := authUC.Register(context.Background(), dto.RegisterRequest{Email: "  User@Example.COM ", Password: "strongpassword"})
	if err != nil {
		t.Fatalf("Register failed: %v", err)
	}
	if res.User.Email != "user@example.com" {
		t.Fatalf("email = %q, want the lower-cased address", res.User.Email)
	}
	if repo.byEmail["user@example.com"] == nil {
		t.Fatal("user was not stored under the normalized address")
	}
}

func TestLogin_RejectsEmptyPassword(t *testing.T) {
	authUC, _ := newAuthUseCase()
	if _, err := authUC.Login(context.Background(), dto.LoginRequest{Email: "user@example.com"}); err == nil {
		t.Fatal("login without a password must be rejected")
	}
}

func TestSetPIN_RejectsNonDigits(t *testing.T) {
	authUC, repo := newAuthUseCase()
	res, err := authUC.Register(context.Background(), dto.RegisterRequest{Email: "user@example.com", Password: "strongpassword"})
	if err != nil {
		t.Fatalf("Register failed: %v", err)
	}
	userID := res.User.ID

	if err := authUC.SetPIN(context.Background(), userID, "12345a"); err == nil {
		t.Fatal("a PIN with a non-digit must be rejected")
	}
	if repo.byID[userID].PINHash != "" {
		t.Fatal("no PIN hash may be stored for an invalid PIN")
	}
	if err := authUC.SetPIN(context.Background(), userID, "123456"); err != nil {
		t.Fatalf("valid PIN rejected: %v", err)
	}
	if ok, err := authUC.VerifyPIN(context.Background(), userID, "123456"); err != nil || !ok {
		t.Fatalf("VerifyPIN = %v, %v, want true", ok, err)
	}
}

func TestVerifyPIN_RejectsWrongPin(t *testing.T) {
	authUC, _ := newAuthUseCase()
	res, err := authUC.Register(context.Background(), dto.RegisterRequest{Email: "user@example.com", Password: "strongpassword"})
	if err != nil {
		t.Fatalf("Register failed: %v", err)
	}
	if err := authUC.SetPIN(context.Background(), res.User.ID, "123456"); err != nil {
		t.Fatalf("SetPIN failed: %v", err)
	}
	ok, err := authUC.VerifyPIN(context.Background(), res.User.ID, "654321")
	if err != nil {
		t.Fatalf("VerifyPIN failed: %v", err)
	}
	if ok {
		t.Fatal("a wrong PIN must not verify")
	}
}

func TestVerifyPIN_RequiresDigits(t *testing.T) {
	authUC, _ := newAuthUseCase()
	res, _ := authUC.Register(context.Background(), dto.RegisterRequest{Email: "user@example.com", Password: "strongpassword"})
	_, err := authUC.VerifyPIN(context.Background(), res.User.ID, "abcdef")
	if err == nil || !strings.Contains(err.Error(), "6 digits") {
		t.Fatalf("err = %v, want a digit validation error", err)
	}
}
