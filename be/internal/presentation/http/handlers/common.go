package handlers

import (
	"context"

	"github.com/danielgtaylor/huma/v2"
	"github.com/google/uuid"
)

type contextKey string

const (
	UserIDKey   contextKey = "user_id"
	EmailKey    contextKey = "email"
	DeviceIDKey contextKey = "device_id"
)

// GetUserID extracts authenticated user ID from context
func GetUserID(ctx context.Context) (uuid.UUID, error) {
	val := ctx.Value(UserIDKey)
	if val == nil {
		return uuid.Nil, huma.Error401Unauthorized("Authentication required")
	}
	id, ok := val.(uuid.UUID)
	if !ok {
		return uuid.Nil, huma.Error401Unauthorized("Invalid authentication context")
	}
	return id, nil
}

// GetDeviceID extracts optional authorized device ID from context
func GetDeviceID(ctx context.Context) *uuid.UUID {
	val := ctx.Value(DeviceIDKey)
	if val == nil {
		return nil
	}
	if id, ok := val.(uuid.UUID); ok {
		return &id
	}
	return nil
}

// MessageOutput is a common JSON response body containing a status message
type MessageOutput struct {
	Body struct {
		Message string `json:"message" example:"Operation completed successfully"`
	}
}
