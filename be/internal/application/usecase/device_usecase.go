package usecase

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

type DeviceUseCase struct {
	deviceRepo repository.DeviceRepository
}

func NewDeviceUseCase(deviceRepo repository.DeviceRepository) *DeviceUseCase {
	return &DeviceUseCase{deviceRepo: deviceRepo}
}

func (uc *DeviceUseCase) RegisterDevice(ctx context.Context, userID uuid.UUID, req dto.RegisterDeviceRequest) (*dto.DeviceDTO, error) {
	name := strings.TrimSpace(req.Name)
	publicKey := strings.TrimSpace(req.PublicKey)
	if name == "" || publicKey == "" {
		return nil, errors.New("name and public_key are required")
	}

	device := entity.Device{
		UserID:    userID,
		PublicKey: publicKey,
		Name:      name,
		CreatedAt: time.Now(),
	}

	if err := uc.deviceRepo.Create(ctx, &device); err != nil {
		return nil, err
	}

	res := dto.ToDeviceDTO(&device)
	return &res, nil
}

func (uc *DeviceUseCase) ListDevices(ctx context.Context, userID uuid.UUID) ([]dto.DeviceDTO, error) {
	devices, err := uc.deviceRepo.ListByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return dto.ToDeviceDTOList(devices), nil
}

func (uc *DeviceUseCase) RevokeDevice(ctx context.Context, userID, deviceID uuid.UUID) error {
	return uc.deviceRepo.Revoke(ctx, userID, deviceID)
}
