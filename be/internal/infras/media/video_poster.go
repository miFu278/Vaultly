package media

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"
	"time"
)

const (
	// posterTimeout bounds one ffmpeg run. A 4K video still yields a first frame
	// in a couple of seconds; anything near this is a broken file.
	posterTimeout = 25 * time.Second

	// posterSeek is how far into the video the frame is taken, so the poster is
	// not a black fade-in. Short clips retry at zero.
	posterSeek = time.Second
)

// VideoPosterer extracts one frame from a video with ffmpeg.
//
// ffmpeg is optional: without the binary the method reports unavailable and
// uploads simply get no poster, which is exactly what happened for every video
// before it was wired in.
type VideoPosterer struct {
	once      sync.Once
	binary    string
	available bool
}

func NewVideoPosterer() *VideoPosterer { return &VideoPosterer{} }

// Available reports whether ffmpeg was found on PATH. The lookup is done once.
func (p *VideoPosterer) Available() bool {
	p.once.Do(func() {
		path, err := exec.LookPath("ffmpeg")
		if err != nil {
			return
		}
		p.binary = path
		p.available = true
	})
	return p.available
}

// GeneratePoster spools the plaintext to a temporary file, because ffmpeg needs a
// seekable input for most containers, then writes one frame as a JPEG no larger
// than maxDim on its long edge.
func (p *VideoPosterer) GeneratePoster(ctx context.Context, r io.Reader, maxDim int) ([]byte, error) {
	if !p.Available() {
		return nil, nil
	}
	if maxDim <= 0 {
		maxDim = MaxThumbnailDimension
	}

	src, err := os.CreateTemp("", "vaultly-poster-*.mp4")
	if err != nil {
		return nil, fmt.Errorf("failed to allocate poster buffer: %w", err)
	}
	srcPath := src.Name()
	defer func() { _ = os.Remove(srcPath) }()

	if _, err := io.Copy(src, r); err != nil {
		_ = src.Close()
		return nil, fmt.Errorf("failed to spool video for poster: %w", err)
	}
	if err := src.Close(); err != nil {
		return nil, fmt.Errorf("failed to close poster buffer: %w", err)
	}

	out, err := os.CreateTemp("", "vaultly-poster-*.jpg")
	if err != nil {
		return nil, fmt.Errorf("failed to allocate poster output: %w", err)
	}
	outPath := out.Name()
	_ = out.Close()
	defer func() { _ = os.Remove(outPath) }()

	// A frame one second in looks like the clip; a very short clip needs zero.
	for _, seek := range []time.Duration{posterSeek, 0} {
		jpeg, runErr := p.extract(ctx, srcPath, outPath, seek, maxDim)
		if runErr != nil {
			return nil, runErr
		}
		if len(jpeg) > 0 {
			return jpeg, nil
		}
	}
	return nil, nil
}

func (p *VideoPosterer) extract(ctx context.Context, srcPath, outPath string, seek time.Duration, maxDim int) ([]byte, error) {
	runCtx, cancel := context.WithTimeout(ctx, posterTimeout)
	defer cancel()

	args := []string{
		"-hide_banner", "-loglevel", "error",
		"-ss", fmt.Sprintf("%.3f", seek.Seconds()),
		"-i", srcPath,
		"-frames:v", "1",
		"-vf", fmt.Sprintf("scale=%d:%d:force_original_aspect_ratio=decrease", maxDim, maxDim),
		"-q:v", "4",
		"-f", "image2",
		"-y", outPath,
	}

	var stderr bytes.Buffer
	cmd := exec.CommandContext(runCtx, p.binary, args...)
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if runCtx.Err() != nil {
			return nil, fmt.Errorf("poster extraction timed out after %s", posterTimeout)
		}
		// A clip shorter than the seek point is not a failure worth a log line.
		return nil, nil
	}

	data, err := os.ReadFile(outPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read poster: %w", err)
	}
	return data, nil
}
