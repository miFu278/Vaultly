package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// BodyLimitMiddleware caps non-multipart request bodies.
//
// Every JSON endpoint otherwise decodes whatever the client sends: a single
// 200 MiB body (a Base64 "image") would be allocated in the container's heap.
// Multipart uploads are skipped because /files/upload installs its own,
// configurable cap from MAX_UPLOAD_MB.
func BodyLimitMiddleware(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		if strings.HasPrefix(c.GetHeader("Content-Type"), "multipart/") {
			c.Next()
			return
		}
		if c.Request.Body != nil {
			c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		}
		c.Next()
	}
}
