package handlers

import (
	"bytes"
	"io"
	"mime/multipart"
	"net/http/httptest"
	"testing"
)

// The upload handler hands fileHeader.Open to the use case twice: once to
// encrypt the payload and once so the thumbnailer can re-read the plaintext.
// Both opens have to start at byte 0, which is what keeps the thumbnail pass
// from needing its own copy of the upload in memory.
func TestMultipartPartReopenableForThumbnail(t *testing.T) {
	payload := bytes.Repeat([]byte("image-bytes-"), 50000) // ~600 KB

	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", "photo.jpg")
	if err != nil {
		t.Fatalf("CreateFormFile failed: %v", err)
	}
	if _, err := part.Write(payload); err != nil {
		t.Fatalf("writing part failed: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("closing writer failed: %v", err)
	}

	req := httptest.NewRequest("POST", "/files/upload", bytes.NewReader(body.Bytes()))
	req.Header.Set("Content-Type", writer.FormDataContentType())
	if err := req.ParseMultipartForm(4 << 20); err != nil {
		t.Fatalf("ParseMultipartForm failed: %v", err)
	}
	defer func() { _ = req.MultipartForm.RemoveAll() }()

	headers := req.MultipartForm.File["file"]
	if len(headers) != 1 {
		t.Fatalf("got %d file parts, want 1", len(headers))
	}

	for attempt := 1; attempt <= 2; attempt++ {
		f, err := headers[0].Open()
		if err != nil {
			t.Fatalf("open %d failed: %v", attempt, err)
		}
		got, err := io.ReadAll(f)
		_ = f.Close()
		if err != nil {
			t.Fatalf("read %d failed: %v", attempt, err)
		}
		if !bytes.Equal(got, payload) {
			t.Fatalf("open %d returned %d bytes that do not match the upload", attempt, len(got))
		}
	}
}
