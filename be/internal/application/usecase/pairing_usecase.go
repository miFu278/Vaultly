package usecase

import (
	"context"
	"crypto/rand"
	"encoding/hex"
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
	// Generate random 32-byte hex token
	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return nil, err
	}
	token := hex.EncodeToString(tokenBytes)
	expiresAt := time.Now().Add(10 * time.Minute)

	pairing := entity.Pairing{
		PairingToken: token,
		PublicKey:    req.PublicKey,
		DeviceName:   req.DeviceName,
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

	if res.Pairing.Status == entity.PairingStatusCompleted && res.Pairing.UserID != nil && res.Pairing.CreatedDeviceID != nil {
		jwtToken, _ := uc.tokenSvc.Generate(service.TokenClaims{
			UserID:   *res.Pairing.UserID,
			Email:    res.UserEmail,
			DeviceID: res.Pairing.CreatedDeviceID,
		})
		resp.JWTToken = &jwtToken
		resp.DeviceID = res.Pairing.CreatedDeviceID
		resp.UserID = res.Pairing.UserID
	}

	return resp, nil
}

func (uc *PairingUseCase) CompletePairing(ctx context.Context, userID uuid.UUID, req dto.PairingCompleteRequest) error {
	newDevice := &entity.Device{
		UserID: userID,
		Name:   "", // Will be populated from pairing session or request
	}

	var wrappedKeys []entity.FileKey
	for _, wk := range req.WrappedKeys {
		wrappedKeys = append(wrappedKeys, entity.FileKey{
			FileID:     wk.DeviceID, // In pairing payload, DeviceID holds the fileID
			WrappedKey: wk.WrappedKey,
			CreatedAt:  time.Now(),
		})
	}

	return uc.pairingRepo.CompletePairingTx(ctx, req.PairingToken, userID, newDevice, wrappedKeys)
}
