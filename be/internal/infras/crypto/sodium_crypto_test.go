package crypto_test

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"testing"

	"golang.org/x/crypto/nacl/box"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/infras/crypto"
)

func TestSodiumCryptoService_Secretstream_Chunked(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()

	// 1. Generate 32-byte File Key
	fileKey, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	if len(fileKey) != 32 {
		t.Fatalf("Expected 32-byte key, got %d", len(fileKey))
	}

	// 2. Test large payload spanning multiple 64KB chunks (e.g. 150KB)
	originalData := make([]byte, 150*1024)
	if _, err := rand.Read(originalData); err != nil {
		t.Fatalf("Failed to generate random test data: %v", err)
	}

	var cipherStream bytes.Buffer
	err = cryptoSvc.EncryptStream(bytes.NewReader(originalData), &cipherStream, fileKey)
	if err != nil {
		t.Fatalf("EncryptStream failed: %v", err)
	}

	if bytes.Equal(originalData, cipherStream.Bytes()) {
		t.Fatal("Ciphertext should not equal plaintext")
	}

	// 3. Decrypt the stream
	var decryptedStream bytes.Buffer
	err = cryptoSvc.DecryptStream(bytes.NewReader(cipherStream.Bytes()), &decryptedStream, fileKey)
	if err != nil {
		t.Fatalf("DecryptStream failed: %v", err)
	}

	if !bytes.Equal(originalData, decryptedStream.Bytes()) {
		t.Fatal("Decrypted data does not match original data")
	}

	// 4. Test In-memory helpers EncryptBytes / DecryptBytes
	smallPlain := []byte("secret photo vault payload 123")
	cipherBytes, header, err := cryptoSvc.EncryptBytes(smallPlain, fileKey)
	if err != nil {
		t.Fatalf("EncryptBytes failed: %v", err)
	}
	if len(header) != 24 {
		t.Fatalf("Expected 24-byte header, got %d", len(header))
	}

	decryptedBytes, err := cryptoSvc.DecryptBytes(cipherBytes, fileKey)
	if err != nil {
		t.Fatalf("DecryptBytes failed: %v", err)
	}
	if !bytes.Equal(smallPlain, decryptedBytes) {
		t.Fatalf("DecryptedBytes mismatch: expected %s, got %s", string(smallPlain), string(decryptedBytes))
	}

	// 5. Test Anti-truncation protection (cutting last 100 bytes of multi-chunk stream)
	truncatedCipher := cipherStream.Bytes()[:cipherStream.Len()-100]
	var truncOut bytes.Buffer
	err = cryptoSvc.DecryptStream(bytes.NewReader(truncatedCipher), &truncOut, fileKey)
	if err == nil {
		t.Fatal("Expected error on truncated stream, but got none")
	}

	// 6. Test Tamper protection (flipping 1 byte in the middle)
	tamperedCipher := make([]byte, cipherStream.Len())
	copy(tamperedCipher, cipherStream.Bytes())
	tamperedCipher[50] ^= 0xFF
	var tamperOut bytes.Buffer
	err = cryptoSvc.DecryptStream(bytes.NewReader(tamperedCipher), &tamperOut, fileKey)
	if err == nil {
		t.Fatal("Expected error on tampered stream, but got none")
	}
}

func TestSodiumCryptoService_CryptoBoxSeal_KeyWrapping(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()

	// 1. Generate X25519 keypair for recipient device
	devPubKey, devPrivKey, err := box.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("GenerateKey failed: %v", err)
	}

	devPubKeyHex := hex.EncodeToString(devPubKey[:])
	devPrivKeyHex := hex.EncodeToString(devPrivKey[:])

	// 2. Generate random 32-byte File Key
	fileKey, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}

	// 3. Wrap File Key using crypto_box_seal (hex public key)
	wrappedKeyHex, err := cryptoSvc.WrapKeyForDevice(fileKey, devPubKeyHex)
	if err != nil {
		t.Fatalf("WrapKeyForDevice failed: %v", err)
	}

	// 4. Unwrap File Key using crypto_box_seal_open
	unwrappedKey, err := cryptoSvc.UnwrapKeyForDevice(wrappedKeyHex, devPubKeyHex, devPrivKeyHex)
	if err != nil {
		t.Fatalf("UnwrapKeyForDevice failed: %v", err)
	}

	if !bytes.Equal(fileKey, unwrappedKey) {
		t.Fatalf("Unwrapped key mismatch: expected %x, got %x", fileKey, unwrappedKey)
	}

	// 5. Test with Base64-encoded public key
	devPubKeyB64 := base64.StdEncoding.EncodeToString(devPubKey[:])
	devPrivKeyB64 := base64.StdEncoding.EncodeToString(devPrivKey[:])

	wrappedKeyHex2, err := cryptoSvc.WrapKeyForDevice(fileKey, devPubKeyB64)
	if err != nil {
		t.Fatalf("WrapKeyForDevice with Base64 pubkey failed: %v", err)
	}

	unwrappedKey2, err := cryptoSvc.UnwrapKeyForDevice(wrappedKeyHex2, devPubKeyB64, devPrivKeyB64)
	if err != nil {
		t.Fatalf("UnwrapKeyForDevice with Base64 keys failed: %v", err)
	}

	if !bytes.Equal(fileKey, unwrappedKey2) {
		t.Fatalf("Unwrapped key mismatch with base64: expected %x, got %x", fileKey, unwrappedKey2)
	}

	// 6. Test with wrong private key -> MUST fail
	_, wrongPrivKey, _ := box.GenerateKey(rand.Reader)
	wrongPrivKeyHex := hex.EncodeToString(wrongPrivKey[:])
	_, err = cryptoSvc.UnwrapKeyForDevice(wrappedKeyHex, devPubKeyHex, wrongPrivKeyHex)
	if err == nil {
		t.Fatal("Expected UnwrapKeyForDevice to fail with wrong private key")
	}
	if !errors.Is(err, domain.ErrDecryptionFailed) {
		t.Fatalf("Expected ErrDecryptionFailed, got %v", err)
	}
}

func TestSodiumCryptoService_ValidateImage(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()

	// JPEG magic bytes: FF D8 FF E0 ...
	jpegData := append([]byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0x00, 0x01}, bytes.Repeat([]byte{0}, 50)...)
	mime, err := cryptoSvc.ValidateImage(jpegData)
	if err != nil {
		t.Fatalf("ValidateImage failed for JPEG: %v", err)
	}
	if mime != "image/jpeg" {
		t.Fatalf("Expected image/jpeg, got %s", mime)
	}

	// PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
	pngData := append([]byte{0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}, bytes.Repeat([]byte{0}, 50)...)
	mime, err = cryptoSvc.ValidateImage(pngData)
	if err != nil {
		t.Fatalf("ValidateImage failed for PNG: %v", err)
	}
	if mime != "image/png" {
		t.Fatalf("Expected image/png, got %s", mime)
	}

	// WebP magic bytes: RIFF....WEBP
	webpData := append([]byte{'R', 'I', 'F', 'F', 0x00, 0x00, 0x00, 0x00, 'W', 'E', 'B', 'P'}, bytes.Repeat([]byte{0}, 50)...)
	mime, err = cryptoSvc.ValidateImage(webpData)
	if err != nil {
		t.Fatalf("ValidateImage failed for WebP: %v", err)
	}
	if mime != "image/webp" {
		t.Fatalf("Expected image/webp, got %s", mime)
	}

	// Invalid data
	invalidData := []byte("plain text not an image")
	_, err = cryptoSvc.ValidateImage(invalidData)
	if err == nil {
		t.Fatal("Expected ValidateImage to fail for non-image data")
	}
}
