package middleware

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/domain/entity"
)

// LogSink receives one entry per finished request. A nil sink only writes to
// stdout.
type LogSink interface {
	Append(entity.AppLog)
}

// maxLoggedMessage bounds the error text copied into a log row.
const maxLoggedMessage = 500

// RequestLogger writes the method, path, status, latency and, for 4xx/5xx, the
// recorded error reason, and hands the same entry to the sink so the deployment
// can be inspected without a shell on the host.
//
// It logs URL.Path, never the full URL: media requests carry the session JWT in
// ?token= because an <img> tag cannot set headers, and gin.Logger would copy that
// token into every access log line.
func RequestLogger(sink LogSink) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		status := c.Writer.Status()
		elapsed := time.Since(start).Round(time.Millisecond)

		line := fmt.Sprintf("%s %s %d %s", c.Request.Method, c.Request.URL.Path, status, elapsed)

		// Only handlers that record c.Error land here, which is the media stream
		// path. Huma formats its own errors without touching the gin context, so
		// those rows carry the status but no reason.
		message := ""
		if status >= 400 && len(c.Errors) > 0 {
			message = strings.Join(strings.Fields(c.Errors.String()), " ")
			if len(message) > maxLoggedMessage {
				message = message[:maxLoggedMessage]
			}
			line += " | " + message
		}

		log.Print(line)

		if sink == nil {
			return
		}
		sink.Append(entity.AppLog{
			Level:      entity.LevelForStatus(status),
			Method:     c.Request.Method,
			Path:       c.Request.URL.Path,
			Status:     status,
			DurationMS: int(elapsed.Milliseconds()),
			UserID:     userIDFrom(c),
			Message:    message,
		})
	}
}

// userIDFrom reads the id the auth middleware put on the gin context. Huma
// routes keep their values in the huma context instead, so those entries carry
// no user id; the path still identifies the request.
func userIDFrom(c *gin.Context) *uuid.UUID {
	value, ok := c.Get("user_id")
	if !ok {
		return nil
	}
	id, ok := value.(uuid.UUID)
	if !ok {
		return nil
	}
	return &id
}
