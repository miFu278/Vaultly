package handlers

import (
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

const (
	// defaultMaxUploadBytes bounds a single upload request body when the
	// deployment does not configure MAX_UPLOAD_MB.
	defaultMaxUploadBytes int64 = 512 << 20 // 512 MiB

	// uploadReadWindow is how long the server waits for an upload body. The
	// global ReadTimeout is tuned for small JSON requests and would abort a
	// video upload mid-flight, so uploads get their own bounded window.
	uploadReadWindow = 15 * time.Minute

	// mediaWriteWindow is how long a media stream may take to flush to a slow
	// client. The global WriteTimeout would truncate video playback.
	mediaWriteWindow = 15 * time.Minute
)

// serveMediaContent streams decrypted media with HTTP range support.
//
// Players (HTML5 <video>, ExoPlayer, AVPlayer) issue Range requests to start
// playback and to seek. Answering 200 with the whole body makes seeking break
// and can fail playback outright on strict players, so range handling is
// delegated to http.ServeContent, which implements 200/206/416/HEAD correctly.
//
// content is a seekable decrypted stream, not a buffer: the caller keeps the
// plaintext on disk/storage and this handler only holds one chunk at a time.
func serveMediaContent(w http.ResponseWriter, r *http.Request, content io.ReadSeeker, contentType string) {
	extendDeadline(w, time.Now().Add(mediaWriteWindow), false)

	h := w.Header()
	h.Set("Content-Type", contentType)
	h.Set("Content-Disposition", "inline")
	h.Set("Cache-Control", "private, max-age=86400")
	// http.ServeContent only advertises this on success paths; a 416 must still
	// tell the player that ranges are supported.
	h.Set("Accept-Ranges", "bytes")

	http.ServeContent(w, r, "", time.Time{}, content)
}

// guardUploadBody caps the request body and widens the read deadline for a
// single upload.
//
// It MUST run before anything reads the request body: gin's PostForm and
// MultipartForm both consume and spool the whole body, so a limit installed
// afterwards would never apply.
func guardUploadBody(c *gin.Context, maxUploadBytes int64) int64 {
	limit := maxUploadBytes
	if limit <= 0 {
		limit = defaultMaxUploadBytes
	}
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, limit)
	extendDeadline(c.Writer, time.Now().Add(uploadReadWindow), true)
	return limit
}

// extendDeadline best-effort overrides the per-connection read/write deadline.
func extendDeadline(w http.ResponseWriter, deadline time.Time, read bool) {
	rc := http.NewResponseController(w)
	if read {
		_ = rc.SetReadDeadline(deadline)
		return
	}
	_ = rc.SetWriteDeadline(deadline)
}

// tooLarge reports whether err came from MaxBytesReader rejecting an oversized
// request body.
func tooLarge(err error) bool {
	var maxErr *http.MaxBytesError
	return errors.As(err, &maxErr)
}
