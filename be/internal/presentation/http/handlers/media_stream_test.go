package handlers

import (
	"bytes"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"vaultly-be/internal/infras/crypto"
)

// Video players stream with Range requests, so the media endpoint must answer
// 206 with the exact slice, advertise Accept-Ranges, and reject bad ranges with
// 416 instead of silently returning the whole body.
func TestServeMediaContent_RangeRequests(t *testing.T) {
	payload := []byte("0123456789")

	tests := []struct {
		name        string
		rangeHeader string
		wantStatus  int
		wantBody    string
		wantRange   string
		wantLength  string
		// 416 responses describe the error body instead of the media, so they
		// carry text/plain; every other case must keep the media type.
		wantContentType string
	}{
		{
			name:            "no range returns full body",
			wantStatus:      http.StatusOK,
			wantBody:        "0123456789",
			wantLength:      "10",
			wantContentType: "video/mp4",
		},
		{
			name:            "prefix range",
			rangeHeader:     "bytes=0-3",
			wantStatus:      http.StatusPartialContent,
			wantBody:        "0123",
			wantRange:       "bytes 0-3/10",
			wantLength:      "4",
			wantContentType: "video/mp4",
		},
		{
			name:            "open ended range",
			rangeHeader:     "bytes=6-",
			wantStatus:      http.StatusPartialContent,
			wantBody:        "6789",
			wantRange:       "bytes 6-9/10",
			wantLength:      "4",
			wantContentType: "video/mp4",
		},
		{
			name:            "suffix range",
			rangeHeader:     "bytes=-2",
			wantStatus:      http.StatusPartialContent,
			wantBody:        "89",
			wantRange:       "bytes 8-9/10",
			wantLength:      "2",
			wantContentType: "video/mp4",
		},
		{
			name:        "unsatisfiable range",
			rangeHeader: "bytes=50-60",
			wantStatus:  http.StatusRequestedRangeNotSatisfiable,
			wantBody:    "invalid range",
			wantRange:   "bytes */10",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/files/abc/view", nil)
			if tc.rangeHeader != "" {
				req.Header.Set("Range", tc.rangeHeader)
			}
			rec := httptest.NewRecorder()

			serveMediaContent(rec, req, bytes.NewReader(payload), "video/mp4")

			res := rec.Result()
			if res.StatusCode != tc.wantStatus {
				t.Fatalf("status = %d, want %d", res.StatusCode, tc.wantStatus)
			}
			if got := rec.Body.String(); !strings.Contains(got, tc.wantBody) {
				t.Fatalf("body = %q, want to contain %q", got, tc.wantBody)
			}
			if got := res.Header.Get("Content-Range"); got != tc.wantRange {
				t.Fatalf("Content-Range = %q, want %q", got, tc.wantRange)
			}
			if tc.wantLength != "" {
				if got := res.Header.Get("Content-Length"); got != tc.wantLength {
					t.Fatalf("Content-Length = %q, want %q", got, tc.wantLength)
				}
			}
			if got := res.Header.Get("Accept-Ranges"); got != "bytes" {
				t.Fatalf("Accept-Ranges = %q, want bytes", got)
			}
			if tc.wantContentType != "" {
				if got := res.Header.Get("Content-Type"); got != tc.wantContentType {
					t.Fatalf("Content-Type = %q, want %q", got, tc.wantContentType)
				}
			}
		})
	}
}

func TestServeMediaContent_HeadAndEmpty(t *testing.T) {
	t.Run("head writes headers only", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodHead, "/files/abc/view", nil)
		rec := httptest.NewRecorder()

		serveMediaContent(rec, req, bytes.NewReader([]byte("0123456789")), "video/mp4")

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want 200", rec.Code)
		}
		if rec.Body.Len() != 0 {
			t.Fatalf("body = %q, want empty", rec.Body.String())
		}
		if got := rec.Header().Get("Content-Length"); got != "10" {
			t.Fatalf("Content-Length = %q, want 10", got)
		}
	})

	t.Run("empty payload", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/files/abc/view", nil)
		rec := httptest.NewRecorder()

		serveMediaContent(rec, req, bytes.NewReader(nil), "image/jpeg")

		if rec.Code != http.StatusOK && rec.Code != http.StatusNoContent {
			t.Fatalf("status = %d, want 200/204", rec.Code)
		}
		if rec.Body.Len() != 0 {
			t.Fatalf("body = %q, want empty", rec.Body.String())
		}
	})
}

// The guard has to be installed on the live request body before any parse:
// gin's PostForm/MultipartForm consume the body, so a later limit is useless.
func TestGuardUploadBody(t *testing.T) {
	gin.SetMode(gin.TestMode)

	t.Run("rejects a body above the limit", func(t *testing.T) {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		c.Request = httptest.NewRequest(
			http.MethodPost,
			"/files/upload",
			strings.NewReader(strings.Repeat("x", 4096)),
		)

		if limit := guardUploadBody(c, 1024); limit != 1024 {
			t.Fatalf("limit = %d, want 1024", limit)
		}

		read, err := io.ReadAll(c.Request.Body)
		if !tooLarge(err) {
			t.Fatalf("expected a MaxBytesError, got %v after %d bytes", err, len(read))
		}
	})

	t.Run("falls back to the default limit", func(t *testing.T) {
		c, _ := gin.CreateTestContext(httptest.NewRecorder())
		c.Request = httptest.NewRequest(
			http.MethodPost,
			"/files/upload",
			strings.NewReader("x"),
		)

		if limit := guardUploadBody(c, 0); limit != defaultMaxUploadBytes {
			t.Fatalf("limit = %d, want %d", limit, defaultMaxUploadBytes)
		}
	})
}

func TestTooLarge(t *testing.T) {
	if tooLarge(nil) {
		t.Fatal("nil error must not be reported as too large")
	}
	if tooLarge(errors.New("unexpected EOF")) {
		t.Fatal("a plain error must not be reported as too large")
	}
	if !tooLarge(&http.MaxBytesError{Limit: 10}) {
		t.Fatal("MaxBytesError must be detected")
	}
	if !tooLarge(errors.Join(errors.New("multipart: "), &http.MaxBytesError{Limit: 10})) {
		t.Fatal("wrapped MaxBytesError must be detected")
	}
}

// The media endpoint serves a seekable decrypted stream instead of a buffer, so
// the ranges a video player asks for must come back with the right headers and
// the exact plaintext bytes.
func TestServeMediaContent_DecryptedStreamRanges(t *testing.T) {
	gin.SetMode(gin.TestMode)

	cryptoSvc := crypto.NewSodiumCryptoService()
	plain := make([]byte, 200*1024)
	for i := range plain {
		plain[i] = byte(i % 251)
	}
	key, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	var cipher bytes.Buffer
	if _, err := cryptoSvc.EncryptStream(bytes.NewReader(plain), &cipher, key); err != nil {
		t.Fatalf("EncryptStream failed: %v", err)
	}
	stored := cipher.Bytes()

	open := func() (io.ReadCloser, error) {
		return io.NopCloser(bytes.NewReader(stored)), nil
	}

	tests := []struct {
		name        string
		rangeHeader string
		wantStatus  int
		wantStart   int
		wantEnd     int
	}{
		{name: "full body", wantStatus: http.StatusOK, wantStart: 0, wantEnd: len(plain)},
		{name: "video seek", rangeHeader: "bytes=131072-131200", wantStatus: http.StatusPartialContent, wantStart: 131072, wantEnd: 131201},
		{name: "open ended", rangeHeader: "bytes=200000-", wantStatus: http.StatusPartialContent, wantStart: 200000, wantEnd: len(plain)},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			initial, err := open()
			if err != nil {
				t.Fatalf("open failed: %v", err)
			}
			stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), initial, func(offset, length int64) (io.ReadCloser, error) {
				return open()
			})
			if err != nil {
				t.Fatalf("OpenDecryptStream failed: %v", err)
			}
			defer stream.Close()

			req := httptest.NewRequest(http.MethodGet, "/files/abc/view", nil)
			if tc.rangeHeader != "" {
				req.Header.Set("Range", tc.rangeHeader)
			}
			rec := httptest.NewRecorder()

			serveMediaContent(rec, req, stream, "video/mp4")

			res := rec.Result()
			if res.StatusCode != tc.wantStatus {
				t.Fatalf("status = %d, want %d", res.StatusCode, tc.wantStatus)
			}
			body := rec.Body.Bytes()
			want := plain[tc.wantStart:tc.wantEnd]
			if !bytes.Equal(body, want) {
				t.Fatalf("body = %d bytes, want %d bytes of plaintext", len(body), len(want))
			}
			if got := res.Header.Get("Content-Length"); got != strconv.Itoa(len(want)) {
				t.Fatalf("Content-Length = %q, want %d", got, len(want))
			}
		})
	}
}
