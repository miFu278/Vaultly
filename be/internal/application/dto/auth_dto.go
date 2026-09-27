package dto

import (
	"time"

	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email" example:"user@example.com"`
	Password string `json:"password" binding:"required,min=8" example:"strongpassword123"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email" example:"user@example.com"`
	Password string `json:"password" binding:"required" example:"strongpassword123"`
}

type UserDTO struct {
	ID        uuid.UUID `json:"id"`
	Email     string    `json:"email"`
	HasPIN    bool      `json:"has_pin"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type SetPINRequest struct {
	PIN string `json:"pin" binding:"required,len=6" example:"123456"`
}

type VerifyPINRequest struct {
	PIN string `json:"pin" binding:"required,len=6" example:"123456"`
}

type VerifyPINResponse struct {
	Valid bool `json:"valid"`
}

type AuthResponse struct {
	Token string  `json:"token"`
	User  UserDTO `json:"user"`
}

func ToUserDTO(u *entity.User) UserDTO {
	return UserDTO{
		ID:        u.ID,
		Email:     u.Email,
		HasPIN:    u.PINHash != "",
		CreatedAt: u.CreatedAt,
		UpdatedAt: u.UpdatedAt,
	}
}
