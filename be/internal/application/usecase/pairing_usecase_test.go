package usecase_test

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
	"vaultly-be/internal/infras/crypto"
)

// stubPairingRepo returns one fixed pairing session.
type stubPairingRepo struct {
	session repository.PairingWithUser
}

func (s *stubPairingRepo) Create(ctx context.Context, p *entity.Pairing) error { return nil }

func (s *stubPairingRepo) GetByToken(ctx context.Context, token string) (*repository.PairingWithUser, error) {
	return &s.session, nil
}

func (s *stubPairingRepo) CompletePairingTx(ctx context.Context, token string, userID uuid.UUID, keys []entity.FileKey) error {
	return nil
}

// completedPairing is a finished pairing session whose device is known.
func completedPairing(expiresAt time.Time, revoked bool) (*stubPairingRepo, *MockDeviceRepo) {
	userID, deviceID := uuid.New(), uuid.New()
	repo := &stubPairingRepo{session: repository.PairingWithUser{
		Pairing: entity.Pairing{
			Status:          entity.PairingStatusCompleted,
			UserID:          &userID,
			CreatedDeviceID: &deviceID,
			ExpiresAt:       expiresAt,
		},
		UserEmail: "user@example.com",
	}}
	devices := NewMockDeviceRepo()
	device := entity.Device{ID: deviceID, UserID: userID, PublicKey: "pk", Name: "New Phone"}
	if revoked {
		revokedAt := time.Now()
		device.RevokedAt = &revokedAt
	}
	devices.devices[deviceID] = device
	return repo, devices
}

// A QR pairing session is only valid for its ten-minute window. Before the fix a
// completed session kept minting fresh 72-hour JWTs forever.
func TestGetPairingStatus_ExpiredSessionGetsNoToken(t *testing.T) {
	repo, devices := completedPairing(time.Now().Add(-24*time.Hour), false)
	tokens := crypto.NewJWTTokenService("test-secret", 1)
	pairingUC := usecase.NewPairingUseCase(repo, devices, nil, tokens)

	res, err := pairingUC.GetPairingStatus(context.Background(), "token")
	if err != nil {
		t.Fatalf("GetPairingStatus failed: %v", err)
	}
	if res.JWTToken != nil {
		t.Fatal("an expired pairing session must not hand out a token")
	}
}

func TestGetPairingStatus_RevokedDeviceGetsNoToken(t *testing.T) {
	repo, devices := completedPairing(time.Now().Add(5*time.Minute), true)
	tokens := crypto.NewJWTTokenService("test-secret", 1)
	pairingUC := usecase.NewPairingUseCase(repo, devices, nil, tokens)

	res, err := pairingUC.GetPairingStatus(context.Background(), "token")
	if err != nil {
		t.Fatalf("GetPairingStatus failed: %v", err)
	}
	if res.JWTToken != nil {
		t.Fatal("a revoked device must not be handed a token")
	}
}

func TestGetPairingStatus_ActiveSessionGetsToken(t *testing.T) {
	repo, devices := completedPairing(time.Now().Add(5*time.Minute), false)
	tokens := crypto.NewJWTTokenService("test-secret", 1)
	pairingUC := usecase.NewPairingUseCase(repo, devices, nil, tokens)

	res, err := pairingUC.GetPairingStatus(context.Background(), "token")
	if err != nil {
		t.Fatalf("GetPairingStatus failed: %v", err)
	}
	if res.JWTToken == nil {
		t.Fatal("an active pairing session must return the device token")
	}
	if _, err := tokens.Validate(*res.JWTToken); err != nil {
		t.Fatalf("returned token does not validate: %v", err)
	}
}

func TestStartPairing_RequiresPublicKeyAndDeviceName(t *testing.T) {
	repo, devices := completedPairing(time.Now().Add(5*time.Minute), false)
	pairingUC := usecase.NewPairingUseCase(repo, devices, nil, crypto.NewJWTTokenService("test-secret", 1))

	if _, err := pairingUC.StartPairing(context.Background(), dto.PairingStartRequest{DeviceName: "New Phone"}); err == nil {
		t.Fatal("a pairing session without a public key must be rejected")
	}
	if _, err := pairingUC.StartPairing(context.Background(), dto.PairingStartRequest{PublicKey: "pk"}); err == nil {
		t.Fatal("a pairing session without a device name must be rejected")
	}

	res, err := pairingUC.StartPairing(context.Background(), dto.PairingStartRequest{PublicKey: "pk", DeviceName: "New Phone"})
	if err != nil {
		t.Fatalf("StartPairing failed: %v", err)
	}
	if len(res.PairingToken) != 64 {
		t.Fatalf("token length = %d, want a 32-byte hex token", len(res.PairingToken))
	}
	_ = domain.ErrPairingNotFound
}
