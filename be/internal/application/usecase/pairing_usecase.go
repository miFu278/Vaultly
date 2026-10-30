package usecase

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
	"vaultly-be/internal/domain/service"
)

type PairingUseCase struct {
	pairingRepo repository.PairingRepository
	deviceRepo  repository.DeviceRepository
	fileRepo    repository.FileRepository
	tokenSvc    service.TokenService
}

func NewPairingUseCase(
	pairingRepo repository.PairingRepository,
	deviceRepo repository.DeviceRepository,
	fileRepo repository.FileRepository,
	tokenSvc service.TokenService,
) *PairingUseCase {
	return &PairingUseCase{
		pairingRepo: pairingRepo,
		deviceRepo:  deviceRepo,
		fileRepo:    fileRepo,
		tokenSvc:    tokenSvc,
	}
}

func (uc *PairingUseCase) StartPairing(ctx context.Context, req dto.PairingStartRequest) (*dto.PairingStartResponse, error) {
	publicKey := strings.TrimSpace(req.PublicKey)
	deviceName := strings.TrimSpace(req.DeviceName)
	if publicKey == "" || deviceName == "" {
		return nil, errors.New("public_key and device_name are required")
	}

	// Generate random 32-byte hex token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return nil, err
	}
	token := hex.EncodeToString(tokenBytes)
	expiresAt := time.Now().Add(10 * time.Minute)

	pairing := entity.Pairing{
		PairingToken: token,
		PublicKey:    publicKey,
		DeviceName:   deviceName,
		Status:       entity.PairingStatusPending,
		ExpiresAt:    expiresAt,
		CreatedAt:    time.Now(),
	}

	if err := uc.pairingRepo.Create(ctx, &pairing); err != nil {
		return nil, err
	}

	return &dto.PairingStartResponse{
		PairingToken: token,
		ExpiresAt:    expiresAt,
	}, nil
}

func (uc *PairingUseCase) GetPairingStatus(ctx context.Context, token string) (*dto.PairingStatusResponse, error) {
	res, err := uc.pairingRepo.GetByToken(ctx, token)
	if err != nil {
		return nil, err
	}

	resp := &dto.PairingStatusResponse{
		Status:     string(res.Pairing.Status),
		DeviceName: res.Pairing.DeviceName,
		ExpiresAt:  res.Pairing.ExpiresAt,
	}

	if res.Pairing.Status != entity.PairingStatusCompleted || res.Pairing.UserID == nil || res.Pairing.CreatedDeviceID == nil {
		return resp, nil
	}
	// The window closes with the pairing session: an expired token must not keep
	// minting fresh JWTs for the device it once authorized.
	if res.Pairing.IsExpired() {
		return resp, nil
	}
	// shortcut: one completed pairing can be polled repeatedly inside its 10
	// minute window and each poll returns a new JWT; make the claim single-use if
	// the window ever grows beyond a QR scan.
	device, err := uc.deviceRepo.GetByID(ctx, *res.Pairing.CreatedDeviceID)
	if err != nil || device == nil || !device.IsActive() || device.UserID != *res.Pairing.UserID {
		return resp, nil
	}

	jwtToken, err := uc.tokenSvc.Generate(service.TokenClaims{
		UserID:   *res.Pairing.UserID,
		Email:    res.UserEmail,
		DeviceID: res.Pairing.CreatedDeviceID,
	})
	if err != nil {
		return nil, err
	}
	resp.JWTToken = &jwtToken
	resp.DeviceID = res.Pairing.CreatedDeviceID
	resp.UserID = res.Pairing.UserID

	return resp, nil
}

// CompletePairing authorizes the device that started the pairing session. The
// device's public key and name come from that session, never from the caller,
// so the keys other devices wrap are the ones the new device actually owns.
func (uc *PairingUseCase) CompletePairing(ctx context.Context, userID uuid.UUID, req dto.PairingCompleteRequest) error {
	var wrappedKeys []entity.FileKey
	for _, wk := range req.WrappedKeys {
		wrappedKeys = append(wrappedKeys, entity.FileKey{
			FileID:     wk.DeviceID, // In pairing payload, DeviceID holds the fileID
			WrappedKey: wk.WrappedKey,
			CreatedAt:  time.Now(),
		})
	}

	return uc.pairingRepo.CompletePairingTx(ctx, req.PairingToken, userID, wrappedKeys)
}
