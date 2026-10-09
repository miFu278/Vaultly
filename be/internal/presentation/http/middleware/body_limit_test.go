package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"vaultly-be/internal/presentation/http/middleware"
)

// A single huge JSON body must be refused before anything decodes it into the
// container's heap, while multipart uploads keep their own larger cap.
func TestBodyLimitMiddleware(t *testing.T) {
	gin.SetMode(gin.TestMode)

	newRouter := func() *gin.Engine {
		r := gin.New()
		r.Use(middleware.BodyLimitMiddleware(16))
		r.POST("/json", func(c *gin.Context) {
			body, err := c.GetRawData()
			if err != nil {
				c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"len": len(body)})
		})
		return r
	}

	t.Run("rejects an oversized json body", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/json", strings.NewReader(strings.Repeat("x", 64)))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		newRouter().ServeHTTP(rec, req)

		if rec.Code != http.StatusRequestEntityTooLarge {
			t.Fatalf("status = %d, want 413", rec.Code)
		}
	})

	t.Run("allows a body within the limit", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/json", strings.NewReader("12345"))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()

		newRouter().ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200", rec.Code)
		}
	})

	t.Run("leaves multipart bodies to the upload handler", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodPost, "/json", strings.NewReader(strings.Repeat("x", 64)))
		req.Header.Set("Content-Type", "multipart/form-data; boundary=xyz")
		rec := httptest.NewRecorder()

		newRouter().ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200", rec.Code)
		}
	})
}
