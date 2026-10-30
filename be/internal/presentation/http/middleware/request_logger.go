package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// RequestLogger writes the method, path, status and latency of a request.
//
// It logs URL.Path, never the full URL: media requests carry the session JWT in
// ?token= because an <img> tag cannot set headers, and gin.Logger would copy that
// token into every access log line.
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		log.Printf("%s %s %d %s", c.Request.Method, c.Request.URL.Path, c.Writer.Status(), time.Since(start).Round(time.Millisecond))
	}
}
