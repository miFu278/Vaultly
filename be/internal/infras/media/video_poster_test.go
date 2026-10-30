package media_test

import (
	"bytes"
	"context"
	"image"
	_ "image/jpeg"
	"os/exec"
	"testing"

	"vaultly-be/internal/infras/media"
)

// The poster path needs ffmpeg on PATH. Where it is missing the extractor must
// report unavailable and return no poster, which is what keeps uploads working
// on an image built without it.
func TestVideoPoster_UnavailableIsNotAnError(t *testing.T) {
	posterer := media.NewVideoPosterer()
	if _, err := exec.LookPath("ffmpeg"); err == nil {
		t.Skip("ffmpeg is installed here; the unavailable branch cannot be exercised")
	}
	if posterer.Available() {
		t.Fatal("Available reported true without ffmpeg on PATH")
	}

	jpeg, err := posterer.GeneratePoster(context.Background(), bytes.NewReader(nil), 512)
	if err != nil {
		t.Fatalf("GeneratePoster without ffmpeg returned an error: %v", err)
	}
	if len(jpeg) != 0 {
		t.Fatalf("GeneratePoster without ffmpeg returned %d bytes, want none", len(jpeg))
	}
}

// With ffmpeg present, a generated clip must yield a JPEG poster.
func TestVideoPoster_ExtractsAFrame(t *testing.T) {
	posterer := media.NewVideoPosterer()
	if !posterer.Available() {
		t.Skip("ffmpeg is not installed; the poster path is not exercised here")
	}

	// A two second synthetic clip, encoded in memory by ffmpeg itself.
	clip := exec.Command("ffmpeg", "-hide_banner", "-loglevel", "error",
		"-f", "lavfi", "-i", "testsrc=size=320x240:rate=15:duration=2",
		"-f", "mp4", "-movflags", "frag_keyframe+empty_moov", "pipe:1")
	var out bytes.Buffer
	clip.Stdout = &out
	if err := clip.Run(); err != nil {
		t.Fatalf("failed to build the test clip: %v", err)
	}

	jpeg, err := posterer.GeneratePoster(context.Background(), bytes.NewReader(out.Bytes()), 512)
	if err != nil {
		t.Fatalf("GeneratePoster failed: %v", err)
	}
	if len(jpeg) < 2 || jpeg[0] != 0xFF || jpeg[1] != 0xD8 {
		t.Fatalf("poster is not a JPEG (%d bytes)", len(jpeg))
	}

	cfg, format, err := image.DecodeConfig(bytes.NewReader(jpeg))
	if err != nil {
		t.Fatalf("poster does not decode: %v", err)
	}
	if format != "jpeg" {
		t.Fatalf("poster format = %s, want jpeg", format)
	}
	if cfg.Width > 512 || cfg.Height > 512 {
		t.Fatalf("poster is %dx%d, want it inside 512", cfg.Width, cfg.Height)
	}
}
