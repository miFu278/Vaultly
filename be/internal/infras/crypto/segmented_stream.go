package crypto

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"io"

	"github.com/openziti/secretstream"
	"vaultly-be/internal/domain"
)

const (
	// SegmentMagic marks a stored payload that is split into independent
	// secretstream segments. Each segment uses its own key, derived from the file
	// key and the segment's position, so moving a segment breaks authentication
	// instead of decrypting into wrong plaintext. Objects with neither magic are
	// legacy single-stream payloads.
	SegmentMagic = "VLTYSEG2"

	// segmentMagicV1 is the first segmented layout: identical framing, but every
	// segment used the file key directly, so reordering two segments went
	// unnoticed. It is still read so objects written before the change work.
	segmentMagicV1 = "VLTYSEG1"

	// SegmentPlainSize is the plaintext size of every segment but the last. It
	// bounds the network cost of serving a byte range: a player asking for one
	// small range pays at most one segment, and the first bytes of a video arrive
	// after one segment instead of after the whole file. Smaller segments mean
	// less waste on small ranges but more storage requests per playback.
	SegmentPlainSize int64 = 1 << 20

	// segmentHeaderSize is magic (8) + plaintext size (8) + segment size (4).
	segmentHeaderSize = int64(len(SegmentMagic) + 8 + 4)
)

// segmentKey derives the secretstream key for one segment position. Binding the
// index into the key is what makes a swapped, duplicated or transplanted
// segment fail authentication instead of decrypting into plausible plaintext.
func segmentKey(master []byte, index int) []byte {
	var idx [4]byte
	binary.BigEndian.PutUint32(idx[:], uint32(index))
	mac := hmac.New(sha256.New, master)
	mac.Write([]byte(SegmentMagic))
	mac.Write(idx[:])
	return mac.Sum(nil)
}

// EncryptSegmentedStream encrypts r into w as a sequence of independent
// secretstream segments.
//
// Layout: [8B magic][u64 plaintextSize][u32 segmentPlainSize][segments...].
// Every segment but the last holds SegmentPlainSize plaintext bytes, so a reader
// derives each segment's ciphertext offset in O(1) -- no index to fetch and no
// need to walk the object to reach a byte range.
//
// It returns the plaintext size and the first segment's stream header, which
// callers keep as the payload nonce. w must be seekable: the object header
// carries the plaintext size, which is only known after the payload is read.
func (s *SodiumCryptoService) EncryptSegmentedStream(r io.Reader, w io.WriteSeeker, key []byte) (int64, []byte, error) {
	if len(key) != 32 {
		return 0, nil, domain.ErrInvalidKeyLength
	}
	if _, err := w.Write(make([]byte, segmentHeaderSize)); err != nil {
		return 0, nil, fmt.Errorf("failed to write segment header: %w", err)
	}

	var plainSize int64
	var firstHeader []byte
	index := 0
	seg := make([]byte, SegmentPlainSize)
	for {
		n, err := io.ReadFull(r, seg)
		if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
			return 0, nil, fmt.Errorf("failed to read upload: %w", err)
		}
		// An empty payload still gets one (empty) segment so it decrypts to an
		// empty plaintext instead of looking corrupt.
		if n > 0 || plainSize == 0 {
			header, encErr := s.EncryptStream(bytes.NewReader(seg[:n]), w, segmentKey(key, index))
			if encErr != nil {
				return 0, nil, encErr
			}
			if firstHeader == nil {
				firstHeader = header
			}
			index++
		}
		plainSize += int64(n)
		if err == io.EOF || err == io.ErrUnexpectedEOF {
			break
		}
	}

	header := make([]byte, 0, segmentHeaderSize)
	header = append(header, SegmentMagic...)
	header = binary.BigEndian.AppendUint64(header, uint64(plainSize))
	header = binary.BigEndian.AppendUint32(header, uint32(SegmentPlainSize))
	if _, err := w.Seek(0, io.SeekStart); err != nil {
		return 0, nil, fmt.Errorf("failed to rewind for segment header: %w", err)
	}
	if _, err := w.Write(header); err != nil {
		return 0, nil, fmt.Errorf("failed to write segment header: %w", err)
	}
	return plainSize, firstHeader, nil
}

// cipherLenForPlainLen is the ciphertext length EncryptStream produces for n
// plaintext bytes: a 24-byte header plus, per chunk, a 4-byte length prefix and
// StreamABytes of authentication data.
func cipherLenForPlainLen(n int64) int64 {
	chunks := (n + DefaultChunkSize - 1) / DefaultChunkSize
	if chunks < 1 {
		chunks = 1
	}
	return int64(secretstream.StreamHeaderBytes) + n + int64(4+secretstream.StreamABytes)*chunks
}

// PlaintextSizeForCipherLen derives the plaintext length of a legacy
// single-stream payload (written by EncryptStream) from the length of the stored
// ciphertext. It reports false when the length cannot be produced by
// EncryptStream.
func PlaintextSizeForCipherLen(cipherLen int64) (int64, bool) {
	const (
		header   = int64(secretstream.StreamHeaderBytes) // 24
		overhead = int64(4 + secretstream.StreamABytes)  // 21
		full     = DefaultChunkSize + overhead           // one full chunk on the wire
	)
	if cipherLen < header+overhead {
		return 0, false
	}
	chunks := (cipherLen - header + full - 1) / full
	plain := cipherLen - header - overhead*chunks
	if plain < 0 {
		return 0, false
	}
	if plain == 0 && chunks == 1 { // empty stream: one 0-byte final chunk
		return 0, true
	}
	if plain > (chunks-1)*DefaultChunkSize && plain <= chunks*DefaultChunkSize {
		return plain, true
	}
	return 0, false
}

// segmentedFormatV1 reports whether head carries the first segmented magic,
// whose segments share one key.
func segmentedFormatV1(head []byte) bool {
	return string(head[:len(segmentMagicV1)]) == segmentMagicV1
}

// parseSegmentedHeader turns the fixed segment header plus the stored ciphertext
// size into the segment layout, and validates that the two agree.
func parseSegmentedHeader(head []byte, cipherLen int64) ([]segment, error) {
	if int64(len(head)) < segmentHeaderSize {
		return nil, fmt.Errorf("%w: truncated segment header", domain.ErrDecryptionFailed)
	}
	plainSize := int64(binary.BigEndian.Uint64(head[8:16]))
	segPlain := int64(binary.BigEndian.Uint32(head[16:20]))
	if plainSize < 0 || segPlain <= 0 {
		return nil, fmt.Errorf("%w: invalid segment header", domain.ErrDecryptionFailed)
	}

	count := (plainSize + segPlain - 1) / segPlain
	if count < 1 {
		count = 1
	}
	fullCipher := cipherLenForPlainLen(segPlain)
	lastPlain := plainSize - (count-1)*segPlain
	lastCipher := cipherLenForPlainLen(lastPlain)
	if segmentHeaderSize+(count-1)*fullCipher+lastCipher != cipherLen {
		return nil, fmt.Errorf("%w: segment index does not match stored size", domain.ErrDecryptionFailed)
	}

	segs := make([]segment, 0, count)
	offset := int64(segmentHeaderSize)
	for i := int64(0); i < count; i++ {
		cipherLen := fullCipher
		plainLen := segPlain
		if i == count-1 {
			cipherLen = lastCipher
			plainLen = lastPlain
		}
		segs = append(segs, segment{
			cipherOffset: offset,
			cipherLen:    cipherLen,
			plainOffset:  i * segPlain,
			plainLen:     plainLen,
		})
		offset += cipherLen
	}
	return segs, nil
}

// legacySegments wraps a payload written before segmenting existed as a single
// segment that starts with its own secretstream header.
func legacySegments(cipherLen int64) ([]segment, error) {
	plain, ok := PlaintextSizeForCipherLen(cipherLen)
	if !ok {
		return nil, fmt.Errorf("%w: unexpected payload size %d", domain.ErrDecryptionFailed, cipherLen)
	}
	return []segment{{
		cipherOffset: 0,
		cipherLen:    cipherLen,
		plainOffset:  0,
		plainLen:     plain,
	}}, nil
}
