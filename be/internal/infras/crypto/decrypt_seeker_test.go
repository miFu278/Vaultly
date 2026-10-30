package crypto_test

import (
	"bytes"
	"encoding/binary"
	"io"
	"testing"

	"vaultly-be/internal/infras/crypto"
)

// memWriteSeeker is an in-memory io.WriteSeeker: the segmented writer patches its
// header after the payload has been written.
type memWriteSeeker struct {
	buf []byte
	pos int64
}

func (m *memWriteSeeker) Write(p []byte) (int, error) {
	end := m.pos + int64(len(p))
	if end > int64(len(m.buf)) {
		grown := make([]byte, end)
		copy(grown, m.buf)
		m.buf = grown
	}
	copy(m.buf[m.pos:], p)
	m.pos = end
	return len(p), nil
}

func (m *memWriteSeeker) Seek(offset int64, whence int) (int64, error) {
	switch whence {
	case io.SeekStart:
		m.pos = offset
	case io.SeekCurrent:
		m.pos += offset
	case io.SeekEnd:
		m.pos = int64(len(m.buf)) + offset
	}
	return m.pos, nil
}

// object is a stored payload plus the range reads a reader performs on it.
type object struct {
	data   []byte
	fetch  func(offset, length int64) (io.ReadCloser, error)
	ranges []rangeRead
}

type rangeRead struct {
	offset int64
	length int64
}

func newObject(data []byte) *object {
	o := &object{data: data}
	o.fetch = func(offset, length int64) (io.ReadCloser, error) {
		o.ranges = append(o.ranges, rangeRead{offset, length})
		return io.NopCloser(bytes.NewReader(data[offset : offset+length])), nil
	}
	return o
}

// plainSizes exercises the interesting boundaries: empty, one byte, a full
// 64 KiB chunk, a full segment, and one byte past each.
var plainSizes = []int{
	0, 1, 1024,
	64*1024 - 1, 64 * 1024, 64*1024 + 1,
	int(crypto.SegmentPlainSize) - 1,
	int(crypto.SegmentPlainSize),
	int(crypto.SegmentPlainSize) + 1,
	int(crypto.SegmentPlainSize) + 3*64*1024,
	2*int(crypto.SegmentPlainSize) + 7,
}

func pattern(n int) []byte {
	out := make([]byte, n)
	for i := range out {
		out[i] = byte(i%251 + 1)
	}
	return out
}

func encryptSegmented(t *testing.T, plain []byte) ([]byte, []byte) {
	t.Helper()
	cryptoSvc := crypto.NewSodiumCryptoService()
	key, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	var out memWriteSeeker
	size, _, err := cryptoSvc.EncryptSegmentedStream(bytes.NewReader(plain), &out, key)
	if err != nil {
		t.Fatalf("EncryptSegmentedStream failed: %v", err)
	}
	if size != int64(len(plain)) {
		t.Fatalf("reported plaintext size %d, want %d", size, len(plain))
	}
	return out.buf, key
}

// The header must let the reader derive every segment offset without a table.
// fullSegmentCipherLen is the ciphertext size EncryptStream produces for exactly
// SegmentPlainSize bytes, which is what SegmentPlainSize implies.
func TestSegmentedLayout_FullSegmentCipherLen(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	key, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	var out memWriteSeeker
	if _, _, err := cryptoSvc.EncryptSegmentedStream(bytes.NewReader(pattern(int(crypto.SegmentPlainSize)*2)), &out, key); err != nil {
		t.Fatalf("EncryptSegmentedStream failed: %v", err)
	}

	// The second segment must start exactly where the fixed-size layout says.
	obj := newObject(out.buf)
	stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(out.buf)), io.NopCloser(bytes.NewReader(out.buf)), obj.fetch)
	if err != nil {
		t.Fatalf("OpenDecryptStream failed: %v", err)
	}
	defer stream.Close()

	if _, err := stream.Seek(crypto.SegmentPlainSize, io.SeekStart); err != nil {
		t.Fatalf("Seek failed: %v", err)
	}
	got := make([]byte, 16)
	if _, err := io.ReadFull(stream, got); err != nil {
		t.Fatalf("ReadFull failed: %v", err)
	}
	plain := pattern(int(crypto.SegmentPlainSize) * 2)
	if !bytes.Equal(got, plain[crypto.SegmentPlainSize:crypto.SegmentPlainSize+16]) {
		t.Fatal("segment boundary read did not match the plaintext")
	}
	if len(obj.ranges) != 1 || obj.ranges[0].offset != int64(len(crypto.SegmentMagic)+8+4)+fullSegmentLen() {
		t.Fatalf("second segment read from %v, want offset %d", obj.ranges, int64(len(crypto.SegmentMagic)+8+4)+fullSegmentLen())
	}
}

func TestSegmentedStream_RoundTrip(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()

	for _, size := range plainSizes {
		stored, key := encryptSegmented(t, pattern(size))
		obj := newObject(stored)

		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), obj.fetch)
		if err != nil {
			t.Fatalf("size %d: OpenDecryptStream failed: %v", size, err)
		}
		if stream.Size() != int64(size) {
			t.Fatalf("size %d: Size = %d", size, stream.Size())
		}
		all, err := io.ReadAll(stream)
		if err != nil {
			t.Fatalf("size %d: ReadAll failed: %v", size, err)
		}
		if !bytes.Equal(all, pattern(size)) {
			t.Fatalf("size %d: plaintext mismatch (%d bytes read)", size, len(all))
		}
		_ = stream.Close()
	}
}

// A video player that seeks near the end must not decrypt the whole object: the
// point of segmenting is that a range costs at most one segment.
func TestSegmentedStream_TailSeekReadsOneSegment(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	size := 3*int(crypto.SegmentPlainSize) + 12345
	stored, key := encryptSegmented(t, pattern(size))
	obj := newObject(stored)

	stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), obj.fetch)
	if err != nil {
		t.Fatalf("OpenDecryptStream failed: %v", err)
	}
	defer stream.Close()

	// http.ServeContent probes the size and seeks back before every response.
	if _, err := stream.Seek(0, io.SeekEnd); err != nil {
		t.Fatalf("Seek(End) failed: %v", err)
	}
	if _, err := stream.Seek(0, io.SeekStart); err != nil {
		t.Fatalf("Seek(Start) failed: %v", err)
	}
	if len(obj.ranges) != 0 {
		t.Fatalf("size probe performed %d range reads, want 0", len(obj.ranges))
	}

	start := int64(size) - 10
	if _, err := stream.Seek(start, io.SeekStart); err != nil {
		t.Fatalf("Seek failed: %v", err)
	}
	tail, err := io.ReadAll(stream)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if !bytes.Equal(tail, pattern(size)[start:]) {
		t.Fatal("tail read did not match the plaintext")
	}

	if len(obj.ranges) != 1 {
		t.Fatalf("tail seek performed %d range reads, want 1: %v", len(obj.ranges), obj.ranges)
	}
	wantOffset := int64(len(crypto.SegmentMagic)+8+4) + 3*fullSegmentLen()
	if obj.ranges[0].offset != wantOffset {
		t.Fatalf("range read at %d, want the last segment at %d", obj.ranges[0].offset, wantOffset)
	}
}

// fullSegmentLen mirrors the layout: a full segment carries SegmentPlainSize
// plaintext bytes plus a 4-byte length prefix and 17 authentication bytes per
// 64 KiB chunk.
func fullSegmentLen() int64 {
	return 24 + crypto.SegmentPlainSize + 21*(crypto.SegmentPlainSize/65536)
}

func TestSegmentedStream_SeeksWithinAndAcrossSegments(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	size := 2*int(crypto.SegmentPlainSize) + 5000
	plain := pattern(size)
	stored, key := encryptSegmented(t, plain)

	t.Run("forward inside a segment reuses the open segment", func(t *testing.T) {
		obj := newObject(stored)
		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), obj.fetch)
		if err != nil {
			t.Fatalf("OpenDecryptStream failed: %v", err)
		}
		defer stream.Close()

		if _, err := stream.Seek(1000, io.SeekStart); err != nil {
			t.Fatalf("Seek failed: %v", err)
		}
		window := make([]byte, 64)
		if _, err := io.ReadFull(stream, window); err != nil {
			t.Fatalf("ReadFull failed: %v", err)
		}
		if _, err := stream.Seek(2*1000, io.SeekStart); err != nil {
			t.Fatalf("Seek failed: %v", err)
		}
		if _, err := io.ReadFull(stream, window); err != nil {
			t.Fatalf("ReadFull failed: %v", err)
		}
		if !bytes.Equal(window, plain[2000:2064]) {
			t.Fatal("forward seek did not read the right plaintext")
		}
		if len(obj.ranges) != 0 {
			t.Fatalf("in-segment seeks performed %d range reads, want 0", len(obj.ranges))
		}
	})

	t.Run("across a segment boundary", func(t *testing.T) {
		obj := newObject(stored)
		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), obj.fetch)
		if err != nil {
			t.Fatalf("OpenDecryptStream failed: %v", err)
		}
		defer stream.Close()

		// Straddle the first boundary to prove reads continue into the next segment.
		start := int64(crypto.SegmentPlainSize) - 8
		if _, err := stream.Seek(start, io.SeekStart); err != nil {
			t.Fatalf("Seek failed: %v", err)
		}
		window := make([]byte, 32)
		if _, err := io.ReadFull(stream, window); err != nil {
			t.Fatalf("ReadFull failed: %v", err)
		}
		if !bytes.Equal(window, plain[start:start+32]) {
			t.Fatal("boundary read did not match the plaintext")
		}
	})

	t.Run("backwards seek re-reads only its segment", func(t *testing.T) {
		obj := newObject(stored)
		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), obj.fetch)
		if err != nil {
			t.Fatalf("OpenDecryptStream failed: %v", err)
		}
		defer stream.Close()

		_, _ = io.ReadAll(stream) // walk every segment once
		// Segment 0 arrives with the initial stream; the other two are ranged.
		if len(obj.ranges) != 2 {
			t.Fatalf("sequential read performed %d range reads, want 2", len(obj.ranges))
		}

		if _, err := stream.Seek(5, io.SeekStart); err != nil {
			t.Fatalf("Seek failed: %v", err)
		}
		head := make([]byte, 8)
		if _, err := io.ReadFull(stream, head); err != nil {
			t.Fatalf("ReadFull failed: %v", err)
		}
		if !bytes.Equal(head, plain[5:13]) {
			t.Fatal("rewind read did not match the plaintext")
		}
		if len(obj.ranges) != 3 {
			t.Fatalf("rewind performed %d range reads, want 3 total", len(obj.ranges))
		}
	})
}

// Objects written before segmenting existed must keep working.
func TestOpenDecryptStream_LegacyPayload(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	key, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	plain := pattern(150 * 1024)
	var cipher bytes.Buffer
	if _, err := cryptoSvc.EncryptStream(bytes.NewReader(plain), &cipher, key); err != nil {
		t.Fatalf("EncryptStream failed: %v", err)
	}
	stored := cipher.Bytes()
	obj := newObject(stored)

	stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), obj.fetch)
	if err != nil {
		t.Fatalf("OpenDecryptStream failed: %v", err)
	}
	defer stream.Close()

	if stream.Size() != int64(len(plain)) {
		t.Fatalf("Size = %d, want %d", stream.Size(), len(plain))
	}
	all, err := io.ReadAll(stream)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if !bytes.Equal(all, plain) {
		t.Fatal("legacy payload did not round-trip")
	}

	if _, err := stream.Seek(70000, io.SeekStart); err != nil {
		t.Fatalf("Seek failed: %v", err)
	}
	window := make([]byte, 32)
	if _, err := io.ReadFull(stream, window); err != nil {
		t.Fatalf("ReadFull failed: %v", err)
	}
	if !bytes.Equal(window, plain[70000:70032]) {
		t.Fatal("legacy seek did not match the plaintext")
	}
}

func TestOpenDecryptStream_RejectsTamperedAndTruncated(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	plain := pattern(100 * 1024)

	t.Run("tampered", func(t *testing.T) {
		stored, key := encryptSegmented(t, plain)
		stored[len(stored)-1] ^= 0xFF
		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored)), io.NopCloser(bytes.NewReader(stored)), nil)
		if err != nil {
			t.Fatalf("OpenDecryptStream failed: %v", err)
		}
		defer stream.Close()
		if _, err := io.ReadAll(stream); err == nil {
			t.Fatal("a tampered payload must not decrypt")
		}
	})

	t.Run("truncated", func(t *testing.T) {
		stored, key := encryptSegmented(t, plain)
		cut := stored[:len(stored)-16]
		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(cut)), io.NopCloser(bytes.NewReader(cut)), nil)
		if err != nil {
			// A size mismatch is caught when the layout is parsed, which is fine.
			return
		}
		defer stream.Close()
		if _, err := io.ReadAll(stream); err == nil {
			t.Fatal("a truncated payload must not decrypt")
		}
	})

	t.Run("reordered segments", func(t *testing.T) {
		// Two full segments have the same ciphertext length, so a swap keeps the
		// object size and every offset intact. Only the per-segment key can tell.
		stored, key := encryptSegmented(t, pattern(2*int(crypto.SegmentPlainSize)))
		headerLen := int64(len(crypto.SegmentMagic) + 8 + 4)
		segLen := fullSegmentLen()
		first := stored[headerLen : headerLen+segLen]
		second := stored[headerLen+segLen : headerLen+2*segLen]

		swapped := append([]byte{}, stored[:headerLen]...)
		swapped = append(swapped, second...)
		swapped = append(swapped, first...)

		stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(swapped)), io.NopCloser(bytes.NewReader(swapped)), nil)
		if err != nil {
			t.Fatalf("OpenDecryptStream failed: %v", err)
		}
		defer stream.Close()
		if _, err := io.ReadAll(stream); err == nil {
			t.Fatal("a swapped segment must not decrypt")
		}
	})

	t.Run("wrong size", func(t *testing.T) {
		stored, key := encryptSegmented(t, plain)
		if _, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored))+1, io.NopCloser(bytes.NewReader(stored)), nil); err == nil {
			t.Fatal("a payload whose length disagrees with its header must be rejected")
		}
	})
}

// Objects written with the first segmented layout share one key across
// segments; they must stay readable after the per-index key change.
func TestOpenDecryptStream_ReadsFirstSegmentedLayout(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	key, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	plain := pattern(2*int(crypto.SegmentPlainSize) + 100)

	var stored memWriteSeeker
	if _, err := stored.Write(make([]byte, len(crypto.SegmentMagic)+8+4)); err != nil {
		t.Fatalf("writing the placeholder header failed: %v", err)
	}
	for off := 0; off < len(plain); off += int(crypto.SegmentPlainSize) {
		end := off + int(crypto.SegmentPlainSize)
		if end > len(plain) {
			end = len(plain)
		}
		if _, err := cryptoSvc.EncryptStream(bytes.NewReader(plain[off:end]), &stored, key); err != nil {
			t.Fatalf("EncryptStream failed: %v", err)
		}
	}

	header := []byte("VLTYSEG1")
	header = binary.BigEndian.AppendUint64(header, uint64(len(plain)))
	header = binary.BigEndian.AppendUint32(header, uint32(crypto.SegmentPlainSize))
	if _, err := stored.Seek(0, io.SeekStart); err != nil {
		t.Fatalf("Seek failed: %v", err)
	}
	if _, err := stored.Write(header); err != nil {
		t.Fatalf("writing the header failed: %v", err)
	}

	obj := newObject(stored.buf)
	stream, err := cryptoSvc.OpenDecryptStream(key, int64(len(stored.buf)), io.NopCloser(bytes.NewReader(stored.buf)), obj.fetch)
	if err != nil {
		t.Fatalf("OpenDecryptStream failed: %v", err)
	}
	defer stream.Close()

	all, err := io.ReadAll(stream)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if !bytes.Equal(all, plain) {
		t.Fatal("VLTYSEG1 payload did not round-trip")
	}
}

func TestPlaintextSizeForCipherLen(t *testing.T) {
	cryptoSvc := crypto.NewSodiumCryptoService()
	key, err := cryptoSvc.GenerateFileKey()
	if err != nil {
		t.Fatalf("GenerateFileKey failed: %v", err)
	}
	for _, size := range plainSizes {
		var out bytes.Buffer
		if _, err := cryptoSvc.EncryptStream(bytes.NewReader(pattern(size)), &out, key); err != nil {
			t.Fatalf("EncryptStream failed: %v", err)
		}
		got, ok := crypto.PlaintextSizeForCipherLen(int64(out.Len()))
		if !ok {
			t.Fatalf("size %d: length %d reported as invalid", size, out.Len())
		}
		if got != int64(size) {
			t.Fatalf("size %d: derived %d from cipher len %d", size, got, out.Len())
		}
	}
	if _, ok := crypto.PlaintextSizeForCipherLen(24); ok {
		t.Fatal("a payload shorter than the header must be rejected")
	}
}
