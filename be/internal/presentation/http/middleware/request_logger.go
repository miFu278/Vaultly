package middleware

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// RequestLogger writes the method, path, status, latency and, for 4xx/5xx, the
// recorded error reason.
//
// It logs URL.Path, never the full URL: media requests carry the session JWT in
// ?token= because an <img> tag cannot set headers, and gin.Logger would copy that
// token into every access log line.
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		line := fmt.Sprintf("%s %s %d %s", c.Request.Method, c.Request.URL.Path,
			c.Writer.Status(), time.Since(start).Round(time.Millisecond))

		// Without the reason a 400 says nothing: a missing object, a rejected
		// device and a decrypt failure log identically.
		if c.Writer.Status() >= 400 && len(c.Errors) > 0 {
			line += " | " + strings.Join(strings.Fields(c.Errors.String()), " ")
		}

		log.Print(line)
	}
}
