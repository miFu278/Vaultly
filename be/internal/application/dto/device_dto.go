package dto

import (
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type RegisterDeviceRequest struct {
	Name      string `json:"name" binding:"required" example:"Pixel 8 Pro"`
	PublicKey string `json:"public_key" binding:"required" example:"x25519-public-key-hex-or-base64"`
}

type DeviceDTO struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"user_id"`
	PublicKey string     `json:"public_key"`
	Name      string     `json:"name"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at,omitempty"`
}

func ToDeviceDTO(d *entity.Device) DeviceDTO {
	return DeviceDTO{
		ID:        d.ID,
		UserID:    d.UserID,
		PublicKey: d.PublicKey,
		Name:      d.Name,
		CreatedAt: d.CreatedAt,
		RevokedAt: d.RevokedAt,
	}
}

func ToDeviceDTOList(devices []entity.Device) []DeviceDTO {
	list := make([]DeviceDTO, len(devices))
	for i, d := range devices {
		list[i] = ToDeviceDTO(&d)
	}
	return list
}
