package media

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"image"
	"image/draw"
	"image/jpeg"
	"io"

	// Decoders for the formats the upload endpoint accepts.
	_ "image/gif"
	_ "image/png"
)

const (
	// MaxThumbnailDimension is the long edge of a generated preview.
	MaxThumbnailDimension = 512

	// thumbnailQuality trades a little detail for a preview that loads on a phone
	// in a single round trip.
	thumbnailQuality = 80

	// maxSourcePixels rejects decompression bombs before they are decoded into
	// memory: a 20000x20000 PNG would otherwise need gigabytes of heap.
	maxSourcePixels = 50 * 1000 * 1000
)

// ImageThumbnailer generates JPEG previews with the standard library, and video
// posters through ffmpeg when that binary is installed.
type ImageThumbnailer struct {
	videos VideoPosterer
}

func NewImageThumbnailer() *ImageThumbnailer { return &ImageThumbnailer{} }

// VideoPosterAvailable reports whether ffmpeg was found at startup.
func (t *ImageThumbnailer) VideoPosterAvailable() bool { return t.videos.Available() }

// GenerateVideoPoster hands the clip to ffmpeg for a single frame.
func (t *ImageThumbnailer) GenerateVideoPoster(ctx context.Context, r io.Reader) ([]byte, error) {
	return t.videos.GeneratePoster(ctx, r, MaxThumbnailDimension)
}

// Generate decodes a still image and re-encodes it as a small JPEG. It returns
// nil (without error) when the payload is not a still image the standard library
// can decode, which callers treat as "no thumbnail for this file".
func (t *ImageThumbnailer) Generate(r io.ReadSeeker) ([]byte, error) {
	cfg, _, err := image.DecodeConfig(bufio.NewReader(r))
	if err != nil {
		return nil, nil // video, or an image format we do not decode
	}
	if cfg.Width <= 0 || cfg.Height <= 0 {
		return nil, nil
	}
	if int64(cfg.Width)*int64(cfg.Height) > maxSourcePixels {
		return nil, fmt.Errorf("image is too large to thumbnail (%dx%d)", cfg.Width, cfg.Height)
	}
	if _, err := r.Seek(0, io.SeekStart); err != nil {
		return nil, fmt.Errorf("failed to rewind image for thumbnail: %w", err)
	}

	src, _, err := image.Decode(bufio.NewReader(r))
	if err != nil {
		return nil, fmt.Errorf("failed to decode image for thumbnail: %w", err)
	}

	thumb := downscale(src, MaxThumbnailDimension)
	var out bytes.Buffer
	if err := jpeg.Encode(&out, thumb, &jpeg.Options{Quality: thumbnailQuality}); err != nil {
		return nil, fmt.Errorf("failed to encode thumbnail: %w", err)
	}
	return out.Bytes(), nil
}

// downscale shrinks src to fit maxDim on its long edge with a box filter, which
// is both fast and artifact-free for the large reduction a thumbnail needs.
// Images already within maxDim are only converted to RGBA.
func downscale(src image.Image, maxDim int) *image.RGBA {
	bounds := src.Bounds()
	width, height := bounds.Dx(), bounds.Dy()
	if width <= 0 || height <= 0 {
		return image.NewRGBA(image.Rect(0, 0, 1, 1))
	}

	dstWidth, dstHeight := width, height
	if width > maxDim || height > maxDim {
		if width >= height {
			dstWidth = maxDim
			dstHeight = height * maxDim / width
		} else {
			dstHeight = maxDim
			dstWidth = width * maxDim / height
		}
		if dstWidth < 1 {
			dstWidth = 1
		}
		if dstHeight < 1 {
			dstHeight = 1
		}
	}

	// White base so transparent PNGs do not turn black when re-encoded as JPEG.
	dst := image.NewRGBA(image.Rect(0, 0, dstWidth, dstHeight))
	draw.Draw(dst, dst.Bounds(), image.White, image.Point{}, draw.Src)
	if dstWidth == width && dstHeight == height {
		draw.Draw(dst, dst.Bounds(), src, bounds.Min, draw.Over)
		return dst
	}

	// Average each source box onto one destination pixel, sampling at most 4x4
	// points per pixel to keep the cost independent of the reduction factor.
	const maxSamples = 4
	xStep := float64(width) / float64(dstWidth)
	yStep := float64(height) / float64(dstHeight)
	xSamples := int(xStep + 1)
	if xSamples > maxSamples {
		xSamples = maxSamples
	}
	ySamples := int(yStep + 1)
	if ySamples > maxSamples {
		ySamples = maxSamples
	}

	for dy := 0; dy < dstHeight; dy++ {
		y0 := bounds.Min.Y + dy*height/dstHeight
		y1 := bounds.Min.Y + (dy+1)*height/dstHeight
		if y1 <= y0 {
			y1 = y0 + 1
		}
		for dx := 0; dx < dstWidth; dx++ {
			x0 := bounds.Min.X + dx*width/dstWidth
			x1 := bounds.Min.X + (dx+1)*width/dstWidth
			if x1 <= x0 {
				x1 = x0 + 1
			}

			var rSum, gSum, bSum, aSum, count uint64
			for y := y0; y < y1; y += max(1, (y1-y0)/ySamples) {
				for x := x0; x < x1; x += max(1, (x1-x0)/xSamples) {
					r, g, b, a := src.At(x, y).RGBA()
					rSum += uint64(r >> 8)
					gSum += uint64(g >> 8)
					bSum += uint64(b >> 8)
					aSum += uint64(a >> 8)
					count++
				}
			}
			if count == 0 {
				continue
			}
			// Composite over the white base so semi-transparent pixels blend.
			alpha := float64(aSum/count) / 255
			sums := [3]uint64{rSum, gSum, bSum}
			i := dst.PixOffset(dx, dy)
			for c := 0; c < 3; c++ {
				v := float64(sums[c]/count)*alpha + 255*(1-alpha) + 0.5
				if v > 255 {
					v = 255
				}
				dst.Pix[i+c] = uint8(v)
			}
			dst.Pix[i+3] = 255
		}
	}
	return dst
}
