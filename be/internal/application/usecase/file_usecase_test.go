package usecase_test

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"testing"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/nacl/box"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/infras/config"
	"vaultly-be/internal/infras/crypto"
	"vaultly-be/internal/infras/media"
	"vaultly-be/internal/infras/storage"
)

// MockFileRepo implements FileRepository in memory for unit testing
type MockFileRepo struct {
	files    map[uuid.UUID]*entity.File
	fileKeys map[string]entity.FileKey // key: fileID_deviceID
}

func NewMockFileRepo() *MockFileRepo {
	return &MockFileRepo{
		files:    make(map[uuid.UUID]*entity.File),
		fileKeys: make(map[string]entity.FileKey),
	}
}

func (m *MockFileRepo) Create(ctx context.Context, f *entity.File) error {
	m.files[f.ID] = f
	return nil
}

func (m *MockFileRepo) GetByID(ctx context.Context, id, userID uuid.UUID) (*entity.File, error) {
	if f, ok := m.files[id]; ok && f.UserID == userID {
		return f, nil
	}
	return nil, nil
}

func (m *MockFileRepo) GetReadyByID(ctx context.Context, id, userID uuid.UUID) (*entity.File, error) {
	if f, ok := m.files[id]; ok && f.UserID == userID && f.Status == entity.FileStatusReady {
		return f, nil
	}
	return nil, nil
}

func (m *MockFileRepo) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.File, error) {
	var list []entity.File
	for _, f := range m.files {
		if f.UserID == userID && f.Status == entity.FileStatusReady {
			list = append(list, *f)
		}
	}
	return list, nil
}

func (m *MockFileRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status entity.FileStatus) error {
	if f, ok := m.files[id]; ok {
		f.Status = status
	}
	return nil
}

func (m *MockFileRepo) ListByFolder(ctx context.Context, userID uuid.UUID, folderID *uuid.UUID, cursor *time.Time, limit int) ([]entity.File, *time.Time, bool, error) {
	files, err := m.ListByUserID(ctx, userID)
	return files, nil, false, err
}

func (m *MockFileRepo) Delete(ctx context.Context, id, userID uuid.UUID) (string, string, error) {
	if f, ok := m.files[id]; ok && f.UserID == userID {
		key := f.R2ObjectKey
		thumb := f.R2ThumbnailKey
		delete(m.files, id)
		return key, thumb, nil
	}
	return "", "", nil
}

func (m *MockFileRepo) SaveFileKeys(ctx context.Context, fileID uuid.UUID, keys []entity.FileKey) error {
	for _, k := range keys {
		mapKey := fileID.String() + "_" + k.DeviceID.String()
		m.fileKeys[mapKey] = k
	}
	return nil
}

func (m *MockFileRepo) GetFileKey(ctx context.Context, fileID, deviceID uuid.UUID) (*entity.FileKey, error) {
	mapKey := fileID.String() + "_" + deviceID.String()
	if fk, ok := m.fileKeys[mapKey]; ok {
		return &fk, nil
	}
	return nil, nil
}

func (m *MockFileRepo) GetFileKeysForDevice(ctx context.Context, deviceID uuid.UUID) ([]entity.FileKey, error) {
	var list []entity.FileKey
	for _, fk := range m.fileKeys {
		if fk.DeviceID == deviceID {
			list = append(list, fk)
		}
	}
	return list, nil
}

func (m *MockFileRepo) CompleteUploadTx(ctx context.Context, userID, fileID uuid.UUID, keys []entity.FileKey) error {
	if f, ok := m.files[fileID]; ok && f.UserID == userID {
		f.Status = entity.FileStatusReady
		return m.SaveFileKeys(ctx, fileID, keys)
	}
	return nil
}

func (m *MockFileRepo) UpdateFolderID(ctx context.Context, id, userID uuid.UUID, folderID *uuid.UUID) error {
	if f, ok := m.files[id]; ok && f.UserID == userID {
		f.FolderID = folderID
		return nil
	}
	return nil
}

func (m *MockFileRepo) CopyFile(ctx context.Context, id, userID uuid.UUID, targetFolderID *uuid.UUID) (*entity.File, error) {
	if f, ok := m.files[id]; ok && f.UserID == userID {
		newID := uuid.New()
		copyFile := *f
		copyFile.ID = newID
		copyFile.FolderID = targetFolderID
		m.files[newID] = &copyFile
		return &copyFile, nil
	}
	return nil, nil
}

// MockDeviceRepo implements DeviceRepository in memory for unit testing
type MockDeviceRepo struct {
	devices map[uuid.UUID]entity.Device
}

func NewMockDeviceRepo() *MockDeviceRepo {
	return &MockDeviceRepo{devices: make(map[uuid.UUID]entity.Device)}
}

func (m *MockDeviceRepo) Create(ctx context.Context, d *entity.Device) error {
	m.devices[d.ID] = *d
	return nil
}

func (m *MockDeviceRepo) GetByID(ctx context.Context, id uuid.UUID) (*entity.Device, error) {
	if d, ok := m.devices[id]; ok {
		return &d, nil
	}
	return nil, nil
}

func (m *MockDeviceRepo) ListByUserID(ctx context.Context, userID uuid.UUID) ([]entity.Device, error) {
	var list []entity.Device
	for _, d := range m.devices {
		if d.UserID == userID && d.IsActive() {
			list = append(list, d)
		}
	}
	return list, nil
}

func (m *MockDeviceRepo) Revoke(ctx context.Context, userID, deviceID uuid.UUID) error {
	delete(m.devices, deviceID)
	return nil
}

func TestFileUseCase_UploadAndDecryptImage(t *testing.T) {
	fileRepo := NewMockFileRepo()
	deviceRepo := NewMockDeviceRepo()

	cfg := &config.Config{
		R2BucketName:                  "test-bucket",
		PresignedURLExpirationMinutes: 15,
	}
	storageSvc, err := storage.NewS3StorageService(cfg)
	if err != nil {
		t.Fatalf("NewS3StorageService failed: %v", err)
	}

	cryptoSvc := crypto.NewSodiumCryptoService()
	fileUC := usecase.NewFileUseCase(fileRepo, deviceRepo, storageSvc, cryptoSvc, media.NewImageThumbnailer())

	userID := uuid.New()
	deviceID := uuid.New()

	// Generate X25519 keypair for recipient device
	devPubKey, devPrivKey, err := box.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey failed: %v", err)
	}
	devPubKeyHex := hex.EncodeToString(devPubKey[:])
	devPrivKeyHex := hex.EncodeToString(devPrivKey[:])

	_ = deviceRepo.Create(context.Background(), &entity.Device{
		ID:        deviceID,
		UserID:    userID,
		PublicKey: devPubKeyHex,
		Name:      "Test Phone",
	})

	// Valid JPEG data (magic bytes FF D8 FF)
	rawJPEG := append([]byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0x00, 0x01}, bytes.Repeat([]byte("pixeldata"), 100)...)

	// 1. Upload and Encrypt Image using libsodium secretstream + crypto_box_seal
	uploadResp, err := fileUC.UploadEncryptedImage(context.Background(), userID, &deviceID, "vacation.jpg", rawJPEG)
	if err != nil {
		t.Fatalf("UploadEncryptedImage failed: %v", err)
	}

	if uploadResp.FileID == uuid.Nil {
		t.Fatal("Expected valid FileID")
	}
	if uploadResp.ContentType != "image/jpeg" {
		t.Fatalf("Expected contentType image/jpeg, got %s", uploadResp.ContentType)
	}
	if uploadResp.CipherSize <= uploadResp.PlainSize {
		t.Fatalf("CipherSize (%d) should be greater than PlainSize (%d) due to secretstream overhead", uploadResp.CipherSize, uploadResp.PlainSize)
	}

	// 2. Stream and decrypt the image using the device's private key
	dm, err := fileUC.OpenDecryptedMedia(context.Background(), userID, &deviceID, uploadResp.FileID, devPrivKeyHex)
	if err != nil {
		t.Fatalf("OpenDecryptedMedia failed: %v", err)
	}
	defer dm.Close()

	if dm.ContentType != "image/jpeg" {
		t.Fatalf("Expected mimeType image/jpeg, got %s", dm.ContentType)
	}
	if dm.Size != int64(len(rawJPEG)) {
		t.Fatalf("Expected plaintext size %d, got %d", len(rawJPEG), dm.Size)
	}

	decryptedBytes, err := io.ReadAll(dm.Content)
	if err != nil {
		t.Fatalf("reading decrypted media failed: %v", err)
	}

	if !bytes.Equal(rawJPEG, decryptedBytes) {
		t.Fatal("Decrypted image does not match original uploaded image")
	}
}

func TestUploadAndDecryptWithoutDevice(t *testing.T) {
	fileRepo := NewMockFileRepo()
	deviceRepo := NewMockDeviceRepo()
	cfg := &config.Config{
		R2BucketName:                  "test-bucket",
		PresignedURLExpirationMinutes: 15,
	}
	storageSvc, err := storage.NewS3StorageService(cfg)
	if err != nil {
		t.Fatalf("NewS3StorageService failed: %v", err)
	}
	cryptoService := crypto.NewSodiumCryptoService()

	fileUC := usecase.NewFileUseCase(fileRepo, deviceRepo, storageSvc, cryptoService, media.NewImageThumbnailer())
	userID := uuid.New()

	// PNG magic bytes
	rawPNG := append([]byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, bytes.Repeat([]byte("testpngdata"), 50)...)

	// 1. Upload without deviceID and with 0 registered devices
	uploadResp, err := fileUC.UploadEncryptedImage(context.Background(), userID, nil, "screenshot.png", rawPNG)
	if err != nil {
		t.Fatalf("UploadEncryptedImage without device failed: %v", err)
	}

	if uploadResp.ContentType != "image/png" {
		t.Fatalf("Expected contentType image/png, got %s", uploadResp.ContentType)
	}

	// 2. Stream and decrypt directly (as done by GET /files/:id/view without device keys)
	dm, err := fileUC.OpenDecryptedMedia(context.Background(), userID, nil, uploadResp.FileID)
	if err != nil {
		t.Fatalf("OpenDecryptedMedia directly failed: %v", err)
	}
	defer dm.Close()

	if dm.ContentType != "image/png" {
		t.Fatalf("Expected mimeType image/png, got %s", dm.ContentType)
	}

	decryptedBytes, err := io.ReadAll(dm.Content)
	if err != nil {
		t.Fatalf("reading decrypted media failed: %v", err)
	}

	if !bytes.Equal(rawPNG, decryptedBytes) {
		t.Fatal("Decrypted image does not match original uploaded image")
	}
}

// A video-sized upload stores multiple segments, so a range read only has to
// touch the segment that holds it, and videos get no thumbnail.
func TestFileUseCase_StreamUploadAndRangeRead(t *testing.T) {
	fileRepo := NewMockFileRepo()
	deviceRepo := NewMockDeviceRepo()
	cfg := &config.Config{
		R2BucketName:                  "test-bucket",
		PresignedURLExpirationMinutes: 15,
	}
	storageSvc, err := storage.NewS3StorageService(cfg)
	if err != nil {
		t.Fatalf("NewS3StorageService failed: %v", err)
	}
	fileUC := usecase.NewFileUseCase(fileRepo, deviceRepo, storageSvc, crypto.NewSodiumCryptoService(), media.NewImageThumbnailer())

	userID := uuid.New()
	plain := bytes.Repeat([]byte("video-frame-payload;"), 300000) // ~6 MiB: two segments
	rawMP4 := append([]byte{0x00, 0x00, 0x00, 0x18, 'f', 't', 'y', 'p'}, plain...)
	replay := func() (service.ReadSeekCloser, error) {
		return nopSeekCloser{bytes.NewReader(rawMP4)}, nil
	}

	res, err := fileUC.UploadEncryptedStream(context.Background(), userID, nil, "clip.mp4", bytes.NewReader(rawMP4), replay, nil)
	if err != nil {
		t.Fatalf("UploadEncryptedStream failed: %v", err)
	}
	if res.PlainSize != int64(len(rawMP4)) || res.CipherSize <= res.PlainSize {
		t.Fatalf("sizes = plain %d cipher %d, want plain %d and a larger cipher", res.PlainSize, res.CipherSize, len(rawMP4))
	}
	if res.ContentType != "video/mp4" {
		t.Fatalf("content type = %s, want video/mp4", res.ContentType)
	}
	stored := fileRepo.files[res.FileID]
	if stored.R2ThumbnailKey != "" {
		t.Fatalf("video thumbnail key = %q, want empty", stored.R2ThumbnailKey)
	}

	dm, err := fileUC.OpenDecryptedMedia(context.Background(), userID, nil, res.FileID)
	if err != nil {
		t.Fatalf("OpenDecryptedMedia failed: %v", err)
	}
	defer dm.Close()

	if dm.Size != int64(len(rawMP4)) {
		t.Fatalf("media size = %d, want %d", dm.Size, len(rawMP4))
	}
	// A tail seek is what a video player does to read its index atom; it must not
	// have to decrypt the whole object.
	start := int64(len(rawMP4) - 4096)
	if _, err := dm.Content.Seek(start, io.SeekStart); err != nil {
		t.Fatalf("Seek failed: %v", err)
	}
	window := make([]byte, 4096)
	if _, err := io.ReadFull(dm.Content, window); err != nil {
		t.Fatalf("ReadFull failed: %v", err)
	}
	if !bytes.Equal(window, rawMP4[start:]) {
		t.Fatal("ranged read did not match the uploaded payload")
	}
}

// Images get an encrypted preview object next to them so a gallery never has to
// pull a full-resolution photo.
func TestFileUseCase_UploadGeneratesEncryptedThumbnail(t *testing.T) {
	fileRepo := NewMockFileRepo()
	deviceRepo := NewMockDeviceRepo()
	cfg := &config.Config{
		R2BucketName:                  "test-bucket",
		PresignedURLExpirationMinutes: 15,
	}
	storageSvc, err := storage.NewS3StorageService(cfg)
	if err != nil {
		t.Fatalf("NewS3StorageService failed: %v", err)
	}
	fileUC := usecase.NewFileUseCase(fileRepo, deviceRepo, storageSvc, crypto.NewSodiumCryptoService(), media.NewImageThumbnailer())

	// A real 1200x800 JPEG, so the thumbnailer has something to decode.
	src := image.NewRGBA(image.Rect(0, 0, 1200, 800))
	for y := 0; y < 800; y++ {
		for x := 0; x < 1200; x++ {
			src.Set(x, y, color.RGBA{R: uint8(x % 256), G: uint8(y % 256), B: 128, A: 255})
		}
	}
	var rawJPEG bytes.Buffer
	if err := jpeg.Encode(&rawJPEG, src, &jpeg.Options{Quality: 90}); err != nil {
		t.Fatalf("jpeg.Encode failed: %v", err)
	}
	payload := rawJPEG.Bytes()

	userID := uuid.New()
	replay := func() (service.ReadSeekCloser, error) {
		return nopSeekCloser{bytes.NewReader(payload)}, nil
	}
	res, err := fileUC.UploadEncryptedStream(context.Background(), userID, nil, "big.jpg", bytes.NewReader(payload), replay, nil)
	if err != nil {
		t.Fatalf("UploadEncryptedStream failed: %v", err)
	}

	stored := fileRepo.files[res.FileID]
	if stored.R2ThumbnailKey == "" {
		t.Fatal("expected a thumbnail object key on the file record")
	}
	if stored.Size != int64(len(payload)) {
		t.Fatalf("stored size = %d, want the plaintext size %d", stored.Size, len(payload))
	}

	thumb, err := fileUC.OpenDecryptedThumbnail(context.Background(), userID, nil, res.FileID)
	if err != nil {
		t.Fatalf("OpenDecryptedThumbnail failed: %v", err)
	}
	defer thumb.Close()

	thumbBytes, err := io.ReadAll(thumb.Content)
	if err != nil {
		t.Fatalf("reading thumbnail failed: %v", err)
	}
	if len(thumbBytes) == 0 || len(thumbBytes) >= len(payload) {
		t.Fatalf("thumbnail is %d bytes, want fewer than the %d byte original", len(thumbBytes), len(payload))
	}
	cfgImg, format, err := image.DecodeConfig(bytes.NewReader(thumbBytes))
	if err != nil {
		t.Fatalf("thumbnail is not a decodable image: %v", err)
	}
	if format != "jpeg" {
		t.Fatalf("thumbnail format = %s, want jpeg", format)
	}
	if cfgImg.Width != 512 || cfgImg.Height != 341 {
		t.Fatalf("thumbnail is %dx%d, want 512x341", cfgImg.Width, cfgImg.Height)
	}
}

// nopSeekCloser adapts an in-memory reader to the upload replay contract.
type nopSeekCloser struct{ *bytes.Reader }

func (nopSeekCloser) Close() error { return nil }
