package crypto

import (
	"golang.org/x/crypto/bcrypt"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/service"
)

type BcryptHasher struct {
	cost int
}

func NewBcryptHasher() service.PasswordHasher {
	return &BcryptHasher{cost: bcrypt.DefaultCost}
}

func (h *BcryptHasher) Hash(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), h.cost)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

func (h *BcryptHasher) Compare(hashedPassword, password string) error {
	if err := bcrypt.CompareHashAndPassword([]byte(hashedPassword), []byte(password)); err != nil {
		return domain.ErrInvalidCredentials
	}
	return nil
}
