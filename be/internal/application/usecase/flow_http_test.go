package usecase_test

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"crypto/rand"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"golang.org/x/crypto/nacl/box"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/infras/config"
	"vaultly-be/internal/infras/crypto"
	"vaultly-be/internal/infras/logging"
	"vaultly-be/internal/infras/media"
	"vaultly-be/internal/infras/storage"
	presentation "vaultly-be/internal/presentation/http"
)

// fakeFolders satisfies the folder repository; uploads in this flow carry no
// folder, so the store is only there to complete the wiring.
type fakeFolders struct{}

func (fakeFolders) Create(context.Context, *entity.Folder) error { return nil }
func (fakeFolders) GetByID(context.Context, uuid.UUID, uuid.UUID) (*entity.Folder, error) {
	return nil, fmt.Errorf("not found")
}
func (fakeFolders) ListByUserID(context.Context, uuid.UUID) ([]entity.Folder, error) {
	return nil, nil
}
func (fakeFolders) Delete(context.Context, uuid.UUID, uuid.UUID) error { return nil }

// fakeLogs is an in-memory LogRepository so the flow test can prove the sink,
// the repository and the admin endpoint work together.
type fakeLogs struct {
	mu      sync.Mutex
	entries []entity.AppLog
}

func (f *fakeLogs) InsertMany(_ context.Context, entries []entity.AppLog) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, e := range entries {
		e.ID = int64(len(f.entries) + 1)
		if e.CreatedAt.IsZero() {
			e.CreatedAt = time.Now()
		}
		f.entries = append(f.entries, e)
	}
	return nil
}

func (f *fakeLogs) Recent(_ context.Context, limit int, level string) ([]entity.AppLog, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]entity.AppLog, 0, limit)
	for i := len(f.entries) - 1; i >= 0 && len(out) < limit; i-- {
		if level != "" && f.entries[i].Level != level {
			continue
		}
		out = append(out, f.entries[i])
	}
	return out, nil
}

func (f *fakeLogs) DeleteOlderThan(_ context.Context, before time.Time) (int64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	kept := f.entries[:0]
	var removed int64
	for _, e := range f.entries {
		if e.CreatedAt.Before(before) {
			removed++
			continue
		}
		kept = append(kept, e)
	}
	f.entries = kept
	return removed, nil
}

func (f *fakeLogs) all() []entity.AppLog {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]entity.AppLog(nil), f.entries...)
}

// flowServer wires the real router over in-memory repositories and storage.
func flowServer(t *testing.T) (*gin.Engine, *logging.Sink, *fakeLogs) {
	t.Helper()
	gin.SetMode(gin.TestMode)

	files := NewMockFileRepo()
	devices := NewMockDeviceRepo()
	users := newMemoryUserRepo()
	blob, err := storage.NewS3StorageService(&config.Config{})
	if err != nil {
		t.Fatalf("storage: %v", err)
	}

	tokens := crypto.NewJWTTokenService("flow-test-secret", 1)
	sodium := crypto.NewSodiumCryptoService()
	thumbnailer := media.NewImageThumbnailer()

	authUC := usecase.NewAuthUseCase(users, crypto.NewBcryptHasher(), tokens)
	deviceUC := usecase.NewDeviceUseCase(devices)
	folderUC := usecase.NewFolderUseCase(fakeFolders{})
	fileUC := usecase.NewFileUseCase(files, devices, blob, sodium, thumbnailer)
	storageUC := usecase.NewStorageUseCase(users, files)
	pairingUC := usecase.NewPairingUseCase(&stubPairingRepo{}, devices, files, tokens)

	logs := &fakeLogs{}
	sink := logging.NewSink(logs, 24*time.Hour)
	sink.Start()
	t.Cleanup(sink.Close)

	router := gin.New()
	presentation.SetupRoutes(router, presentation.RouterDependencies{
		AuthUseCase:      authUC,
		DeviceUseCase:    deviceUC,
		FolderUseCase:    folderUC,
		FileUseCase:      fileUC,
		StorageUseCase:   storageUC,
		LogUseCase:       usecase.NewLogUseCase(logs),
		PairingUseCase:   pairingUC,
		TokenService:     tokens,
		DeviceRepository: devices,
		LogSink:          sink,
		AdminToken:       flowAdminToken,
	})
	return router, sink, logs
}

const flowAdminToken = "flow-admin-token"

func jpegPayload(t *testing.T) []byte {
	t.Helper()
	src := image.NewRGBA(image.Rect(0, 0, 640, 480))
	for y := 0; y < 480; y++ {
		for x := 0; x < 640; x++ {
			src.Set(x, y, color.RGBA{R: uint8(x % 256), G: uint8(y % 256), B: 90, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, src, &jpeg.Options{Quality: 85}); err != nil {
		t.Fatalf("jpeg: %v", err)
	}
	return buf.Bytes()
}

func doJSON(t *testing.T, router http.Handler, method, path, token string, body []byte) (int, []byte) {
	t.Helper()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec.Code, rec.Body.Bytes()
}

// A single end-to-end pass over what the app does: register, upload, list, view,
// thumbnail, download. Whichever step is broken shows up as a named failure.
func TestFileFlow_ListThenEveryReadPath(t *testing.T) {
	router, sink, logs := flowServer(t)

	code, body := doJSON(t, router, http.MethodPost, "/auth/register", "",
		[]byte(`{"email":"flow@example.com","password":"strongpassword"}`))
	if code != http.StatusOK && code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, body)
	}
	var auth struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(body, &auth); err != nil || auth.Token == "" {
		t.Fatalf("register token: %v %s", err, body)
	}

	// Upload the way the app does: multipart, one part named "file".
	payload := jpegPayload(t)
	var mp bytes.Buffer
	writer := multipart.NewWriter(&mp)
	part, err := writer.CreateFormFile("file", "flow.jpg")
	if err != nil {
		t.Fatalf("multipart: %v", err)
	}
	if _, err := part.Write(payload); err != nil {
		t.Fatalf("multipart write: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("multipart close: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, "/files/upload", bytes.NewReader(mp.Bytes()))
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+auth.Token)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("upload: %d %s", rec.Code, rec.Body.String())
	}
	var uploaded struct {
		FileID         string `json:"file_id"`
		R2ThumbnailKey string `json:"r2_thumbnail_key"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &uploaded); err != nil {
		t.Fatalf("upload decode: %v %s", err, rec.Body.String())
	}
	if uploaded.FileID == "" {
		t.Fatalf("upload returned no file_id: %s", rec.Body.String())
	}
	t.Logf("uploaded %s, thumbnail key %q", uploaded.FileID, uploaded.R2ThumbnailKey)

	// 1. List.
	code, body = doJSON(t, router, http.MethodGet, "/files", auth.Token, nil)
	if code != http.StatusOK {
		t.Fatalf("list: %d %s", code, body)
	}
	var listed []map[string]any
	if err := json.Unmarshal(body, &listed); err != nil {
		t.Fatalf("list decode: %v %s", err, body)
	}
	if len(listed) != 1 {
		t.Fatalf("list has %d items, want 1: %s", len(listed), body)
	}

	get := func(path string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(http.MethodGet, path, nil)
		r.Header.Set("Authorization", "Bearer "+auth.Token)
		w := httptest.NewRecorder()
		router.ServeHTTP(w, r)
		return w
	}

	// 2. Full media.
	view := get("/files/" + uploaded.FileID + "/view")
	if view.Code != http.StatusOK {
		t.Fatalf("view: %d %s", view.Code, view.Body.String())
	}
	if !bytes.Equal(view.Body.Bytes(), payload) {
		t.Fatalf("view returned %d bytes, want the %d uploaded", view.Body.Len(), len(payload))
	}

	// 3. Thumbnail stream, which the gallery grid uses.
	thumb := get("/files/" + uploaded.FileID + "/view?variant=thumb")
	if thumb.Code != http.StatusOK {
		t.Fatalf("view?variant=thumb: %d %s", thumb.Code, thumb.Body.String())
	}
	if thumb.Body.Len() == 0 {
		t.Fatal("thumbnail stream was empty")
	}

	// 4. Presigned thumbnail URL (Huma endpoint).
	code, body = doJSON(t, router, http.MethodGet,
		"/files/"+uploaded.FileID+"/thumbnail", auth.Token, nil)
	if code != http.StatusOK {
		t.Fatalf("thumbnail endpoint: %d %s", code, body)
	}

	// 5. Metadata detail: what "open this file" asks for, without ciphertext.
	code, body = doJSON(t, router, http.MethodGet,
		"/files/"+uploaded.FileID, auth.Token, nil)
	if code != http.StatusOK {
		t.Fatalf("file detail: %d %s", code, body)
	}
	var detail struct {
		ID          string `json:"id"`
		ContentType string `json:"content_type"`
		Size        int64  `json:"size"`
		Status      string `json:"status"`
	}
	if err := json.Unmarshal(body, &detail); err != nil {
		t.Fatalf("detail decode: %v %s", err, body)
	}
	if detail.ID != uploaded.FileID || detail.Status != "ready" {
		t.Fatalf("detail = %+v, want id %s and status ready", detail, uploaded.FileID)
	}
	if detail.ContentType != "image/jpeg" || detail.Size != int64(len(payload)) {
		t.Fatalf("detail = %+v, want image/jpeg of %d bytes", detail, len(payload))
	}

	// A file id that does not exist must be a 404, not an empty payload.
	code, _ = doJSON(t, router, http.MethodGet,
		"/files/"+uuid.NewString(), auth.Token, nil)
	if code != http.StatusNotFound {
		t.Fatalf("missing file detail: %d, want 404", code)
	}

	// 6. Range request, what a video player sends to seek.
	ranged := httptest.NewRequest(http.MethodGet, "/files/"+uploaded.FileID+"/view", nil)
	ranged.Header.Set("Authorization", "Bearer "+auth.Token)
	ranged.Header.Set("Range", "bytes=0-99")
	rw := httptest.NewRecorder()
	router.ServeHTTP(rw, ranged)
	if rw.Code != http.StatusPartialContent {
		t.Fatalf("range view: %d %s", rw.Code, rw.Body.String())
	}
	if !bytes.Equal(rw.Body.Bytes(), payload[:100]) {
		t.Fatalf("range view returned %d bytes, want the first 100", rw.Body.Len())
	}

	// 7. Download is device-only now: a login token must get an actionable 403.
	code, body = doJSON(t, router, http.MethodGet,
		"/files/"+uploaded.FileID+"/download", auth.Token, nil)
	if code != http.StatusForbidden {
		t.Fatalf("download without a device: %d %s, want 403", code, body)
	}

	// 8. Storage dashboard.
	code, body = doJSON(t, router, http.MethodGet, "/storage", auth.Token, nil)
	if code != http.StatusOK {
		t.Fatalf("storage: %d %s", code, body)
	}
	var usage struct {
		UsedBytes  int64 `json:"used_bytes"`
		QuotaBytes int64 `json:"quota_bytes"`
		FileCount  int64 `json:"file_count"`
	}
	if err := json.Unmarshal(body, &usage); err != nil {
		t.Fatalf("storage decode: %v %s", err, body)
	}
	if usage.UsedBytes != int64(len(payload)) || usage.FileCount != 1 {
		t.Fatalf("storage = %+v, want %d bytes over 1 file", usage, len(payload))
	}
	if usage.QuotaBytes <= 0 {
		t.Fatalf("quota = %d, want the account default", usage.QuotaBytes)
	}

	// 9. The request log is readable from outside the host, and the admin token
	// is the only thing standing in front of it.
	sink.Close() // flush what the middleware buffered

	code, body = doJSON(t, router, http.MethodGet, "/admin/logs", "", nil)
	if code != http.StatusUnauthorized {
		t.Fatalf("admin logs without token: %d %s, want 401", code, body)
	}
	code, body = doJSON(t, router, http.MethodGet, "/admin/logs", flowAdminToken, nil)
	if code != http.StatusOK {
		t.Fatalf("admin logs: %d %s", code, body)
	}
	var logPage struct {
		Logs []struct {
			Level   string `json:"level"`
			Path    string `json:"path"`
			Status  int    `json:"status"`
			Message string `json:"message"`
		} `json:"logs"`
	}
	if err := json.Unmarshal(body, &logPage); err != nil {
		t.Fatalf("admin logs decode: %v %s", err, body)
	}
	if len(logPage.Logs) == 0 {
		t.Fatal("admin logs returned nothing; the sink never wrote")
	}

	var sawForbidden, sawOk bool
	for _, entry := range logPage.Logs {
		switch {
		case entry.Status == http.StatusForbidden && entry.Level == "warn":
			sawForbidden = true
		case entry.Status == http.StatusOK && entry.Path == "/files":
			sawOk = true
		}
	}
	if !sawForbidden || !sawOk {
		t.Fatalf("log missing entries (forbidden=%v ok=%v): %+v", sawForbidden, sawOk, logPage.Logs)
	}
	if got := len(logs.all()); got < 5 {
		t.Fatalf("stored %d log entries for the whole flow, want at least 5", got)
	}
}

// The same reads with a paired device token, because those tokens carry a
// device_id and the middleware now re-checks that device on every request.
func TestFileFlow_PairedDeviceTokenCanRead(t *testing.T) {
	router, _, _ := flowServer(t)

	code, body := doJSON(t, router, http.MethodPost, "/auth/register", "",
		[]byte(`{"email":"paired@example.com","password":"strongpassword"}`))
	if code != http.StatusOK && code != http.StatusCreated {
		t.Fatalf("register: %d %s", code, body)
	}
	var auth struct {
		Token string `json:"token"`
		User  struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	_ = json.Unmarshal(body, &auth)

	// Register a device, then mint a token that claims it, the way pairing does.
	pub, _, err := box.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("keypair: %v", err)
	}
	devPub := hex.EncodeToString(pub[:])
	code, body = doJSON(t, router, http.MethodPost, "/devices/register", auth.Token,
		[]byte(`{"name":"Flow Phone","public_key":"`+devPub+`"}`))
	if code != http.StatusOK && code != http.StatusCreated {
		t.Fatalf("device register: %d %s", code, body)
	}
	var device struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &device); err != nil || device.ID == "" {
		t.Fatalf("device decode: %v %s", err, body)
	}

	devID, err := uuid.Parse(device.ID)
	if err != nil {
		t.Fatalf("device id: %v", err)
	}
	userID, err := uuid.Parse(auth.User.ID)
	if err != nil {
		t.Fatalf("user id: %v", err)
	}
	deviceToken, err := crypto.NewJWTTokenService("flow-test-secret", 1).
		Generate(service.TokenClaims{
			UserID:   userID,
			Email:    "paired@example.com",
			DeviceID: &devID,
		})
	if err != nil {
		t.Fatalf("token: %v", err)
	}

	view := func(path, token string) *httptest.ResponseRecorder {
		r := httptest.NewRequest(http.MethodGet, path, nil)
		r.Header.Set("Authorization", "Bearer "+token)
		w := httptest.NewRecorder()
		router.ServeHTTP(w, r)
		return w
	}

	if res := view("/files", deviceToken); res.Code != http.StatusOK {
		t.Fatalf("device list: %d %s", res.Code, res.Body.String())
	}

	// Upload with the device token so the wrapped key row exists for it.
	payload := jpegPayload(t)
	var mp bytes.Buffer
	writer := multipart.NewWriter(&mp)
	part, _ := writer.CreateFormFile("file", "paired.jpg")
	_, _ = part.Write(payload)
	_ = writer.Close()

	req := httptest.NewRequest(http.MethodPost, "/files/upload", bytes.NewReader(mp.Bytes()))
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+deviceToken)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("device upload: %d %s", rec.Code, rec.Body.String())
	}
	var uploaded struct {
		FileID string `json:"file_id"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &uploaded)

	if res := view("/files/"+uploaded.FileID+"/view", deviceToken); res.Code != http.StatusOK {
		t.Fatalf("device view: %d %s", res.Code, res.Body.String())
	}
	if res := view("/files/"+uploaded.FileID+"/view?variant=thumb", deviceToken); res.Code != http.StatusOK {
		t.Fatalf("device thumb: %d %s", res.Code, res.Body.String())
	}
	if res := view("/files/"+uploaded.FileID+"/download", deviceToken); res.Code != http.StatusOK {
		t.Fatalf("device download: %d %s", res.Code, res.Body.String())
	}
}
