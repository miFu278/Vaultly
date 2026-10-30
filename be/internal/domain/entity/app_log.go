package entity

import (
	"time"

	"github.com/google/uuid"
)

// AppLog is one finished HTTP request, kept so the deployment can be inspected
// from anywhere instead of a shell on the host.
type AppLog struct {
	ID         int64      `json:"id"`
	CreatedAt  time.Time  `json:"created_at"`
	Level      string     `json:"level"` // info, warn, error
	Method     string     `json:"method"`
	Path       string     `json:"path"`
	Status     int        `json:"status"`
	DurationMS int        `json:"duration_ms"`
	UserID     *uuid.UUID `json:"user_id,omitempty"`
	Message    string     `json:"message"`
}

// LevelForStatus maps an HTTP status onto the three levels the dashboard filters
// by, so a 500 never gets lost among the 200s.
func LevelForStatus(status int) string {
	switch {
	case status >= 500:
		return "error"
	case status >= 400:
		return "warn"
	default:
		return "info"
	}
}
