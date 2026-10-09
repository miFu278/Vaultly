package crypto

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"sort"

	"github.com/openziti/secretstream"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/service"
)

// maxCipherChunkBytes bounds one chunk read so a corrupt or hostile payload
// cannot make the reader allocate an arbitrary buffer. A chunk holds at most
// DefaultChunkSize plaintext bytes plus the secretstream authentication bytes.
const maxCipherChunkBytes = int64(DefaultChunkSize + secretstream.StreamABytes)

// segment is one independently decryptable part of a stored object: it carries
// its own secretstream header, so it can be fetched and decrypted on its own.
type segment struct {
	cipherOffset int64
	cipherLen    int64
	plainOffset  int64
	plainLen     int64
}

// segmentReader is a seekable plaintext view of a stored object.
//
// Secretstream state is chained inside a segment but segments are independent,
// so a seek only re-reads the segment holding the target: memory stays at one
// 64 KiB chunk and a video seek costs one segment instead of the whole file.
// A legacy single-stream object is the degenerate one-segment case.
type segmentReader struct {
	key     []byte
	total   int64
	segs    []segment
	fetch   func(offset, length int64) (io.ReadCloser, error)
	initial io.ReadCloser // ciphertext stream positioned at the first segment

	idx      int // open segment, -1 when none
	cipher   io.ReadCloser
	dec      secretstream.Decryptor
	chunk    []byte
	buf      []byte // decrypted bytes not handed to the caller yet
	produced int64  // plaintext produced inside the open segment
	final    bool   // the open segment delivered its final tag
	pos      int64  // absolute position of the next delivered byte
	seekTo   int64  // pending seek target
	seeked   bool
	scratch  []byte
}

// OpenDecryptStream detects the stored layout and returns a seekable plaintext
// reader for it. src must be positioned at byte 0 and cipherLen must be its
// exact size; src is reused for the first segment and fetch returns a stream of
// length bytes starting at offset.
func (s *SodiumCryptoService) OpenDecryptStream(
	key []byte,
	cipherLen int64,
	src io.ReadCloser,
	fetch func(offset, length int64) (io.ReadCloser, error),
) (service.DecryptedStream, error) {
	if len(key) != 32 {
		return nil, domain.ErrInvalidKeyLength
	}
	if src == nil && fetch == nil {
		return nil, errors.New("no ciphertext source for decryption")
	}

	probe := make([]byte, segmentHeaderSize)
	n, err := io.ReadFull(src, probe)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		_ = src.Close()
		return nil, fmt.Errorf("failed to read encrypted object: %w", err)
	}

	var segs []segment
	if int64(n) == segmentHeaderSize && string(probe[:len(SegmentMagic)]) == SegmentMagic {
		if segs, err = parseSegmentedHeader(probe, cipherLen); err != nil {
			_ = src.Close()
			return nil, err
		}
		return newSegmentReader(key, segs, src, fetch)
	}

	// Legacy single-stream object: hand back the bytes the probe consumed.
	if segs, err = legacySegments(cipherLen); err != nil {
		_ = src.Close()
		return nil, err
	}
	return newSegmentReader(key, segs, prefixedReadCloser(probe[:n], src), fetch)
}

func newSegmentReader(key []byte, segs []segment, initial io.ReadCloser, fetch func(offset, length int64) (io.ReadCloser, error)) (*segmentReader, error) {
	if len(segs) == 0 {
		return nil, fmt.Errorf("%w: no segments", domain.ErrDecryptionFailed)
	}
	if initial == nil && fetch == nil {
		return nil, errors.New("no ciphertext source for decryption")
	}
	last := segs[len(segs)-1]
	return &segmentReader{
		key:     key,
		total:   last.plainOffset + last.plainLen,
		segs:    segs,
		initial: initial,
		fetch:   fetch,
		idx:     -1,
		scratch: make([]byte, 4096),
	}, nil
}

// Size is the plaintext length, known before the first read.
func (r *segmentReader) Size() int64 { return r.total }

func (r *segmentReader) Read(p []byte) (int, error) {
	if err := r.align(); err != nil {
		return 0, err
	}
	if r.pos >= r.total {
		return 0, io.EOF
	}
	n, err := r.readPlain(p)
	r.pos += int64(n)
	return n, err
}

func (r *segmentReader) Seek(offset int64, whence int) (int64, error) {
	current := r.pos
	if r.seeked {
		current = r.seekTo
	}
	var target int64
	switch whence {
	case io.SeekStart:
		target = offset
	case io.SeekCurrent:
		target = current + offset
	case io.SeekEnd:
		target = r.total + offset
	default:
		return 0, errors.New("invalid seek whence")
	}
	if target < 0 {
		return 0, errors.New("negative seek position")
	}
	r.seekTo, r.seeked = target, true
	return target, nil
}

// align moves the stream to the pending seek target. It runs on the next read,
// so the size probe http.ServeContent performs before every response costs no
// storage I/O at all.
func (r *segmentReader) align() error {
	if !r.seeked {
		return nil
	}
	r.seeked = false

	if r.seekTo >= r.total {
		// At or past the end: nothing to decrypt, reads report EOF.
		r.closeSegment()
		r.pos = r.seekTo
		return nil
	}

	// Seek inside what is already decrypted: just drop buffered plaintext.
	if r.idx >= 0 && r.seekTo < r.pos {
		bufStart := r.segs[r.idx].plainOffset + r.produced - int64(len(r.buf))
		if r.seekTo >= bufStart {
			r.buf = r.buf[r.seekTo-bufStart:]
			r.pos = r.seekTo
			return nil
		}
	}
	if r.idx >= 0 && (r.seekTo < r.pos || !r.holds(r.idx, r.seekTo)) {
		r.closeSegment()
	}
	if r.idx < 0 {
		r.pos = 0
	}

	for r.pos < r.seekTo {
		if r.idx < 0 {
			// Jump straight to the segment holding the target rather than
			// decrypting every segment in between.
			if err := r.openSegment(r.segmentIndex(r.seekTo)); err != nil {
				return err
			}
			continue
		}
		if !r.holds(r.idx, r.seekTo) {
			r.closeSegment()
			continue
		}
		want := r.seekTo - r.pos
		if want > int64(len(r.scratch)) {
			want = int64(len(r.scratch))
		}
		n, err := r.readPlain(r.scratch[:want])
		r.pos += int64(n)
		if err != nil {
			return err
		}
		if n == 0 {
			return io.EOF
		}
	}
	return nil
}

// readPlain produces plaintext from the open segment, moving on to the next
// segment when one ends.
func (r *segmentReader) readPlain(p []byte) (int, error) {
	for len(r.buf) == 0 {
		if err := r.pull(); err != nil {
			return 0, err
		}
	}
	n := copy(p, r.buf)
	r.buf = r.buf[n:]
	return n, nil
}

// pull decrypts the next chunk into the buffer.
func (r *segmentReader) pull() error {
	for {
		if r.idx < 0 {
			if err := r.openSegment(r.segmentIndex(r.pos)); err != nil {
				return err
			}
		}
		seg := r.segs[r.idx]
		if r.produced >= seg.plainLen {
			if r.idx+1 >= len(r.segs) {
				return io.EOF
			}
			if err := r.openSegment(r.idx + 1); err != nil {
				return err
			}
			continue
		}
		if r.final {
			return fmt.Errorf("%w: segment %d ended after %d of %d bytes",
				domain.ErrStreamTruncated, r.idx, r.produced, seg.plainLen)
		}
		plain, err := r.nextChunk()
		if err != nil {
			return err
		}
		r.produced += int64(len(plain))
		if len(plain) == 0 {
			continue
		}
		r.buf = plain
		return nil
	}
}

// nextChunk decrypts one chunk of the open segment.
func (r *segmentReader) nextChunk() ([]byte, error) {
	var lenBuf [4]byte
	if _, err := io.ReadFull(r.cipher, lenBuf[:]); err != nil {
		// A well-formed segment ends with a chunk tagged final, so running out of
		// bytes here means the payload was cut short.
		return nil, fmt.Errorf("%w: %v", domain.ErrStreamTruncated, err)
	}
	chunkLen := int64(binary.BigEndian.Uint32(lenBuf[:]))
	if chunkLen < secretstream.StreamABytes || chunkLen > maxCipherChunkBytes {
		return nil, fmt.Errorf("%w: invalid chunk length %d", domain.ErrDecryptionFailed, chunkLen)
	}
	if int64(cap(r.chunk)) < chunkLen {
		r.chunk = make([]byte, chunkLen)
	}
	r.chunk = r.chunk[:chunkLen]
	if _, err := io.ReadFull(r.cipher, r.chunk); err != nil {
		return nil, fmt.Errorf("%w: %v", domain.ErrStreamTruncated, err)
	}

	plain, tag, err := r.dec.Pull(r.chunk)
	if err != nil {
		return nil, fmt.Errorf("%w: secretstream chunk verification failed: %v", domain.ErrDecryptionFailed, err)
	}
	if tag == secretstream.TagFinal {
		r.final = true
	}
	return plain, nil
}

// openSegment starts segment i, reusing the initial stream for the first one.
func (r *segmentReader) openSegment(i int) error {
	r.closeSegment()

	var src io.ReadCloser
	if r.initial != nil && i == 0 {
		src = r.initial
		r.initial = nil
	} else {
		if r.fetch == nil {
			return fmt.Errorf("%w: no ciphertext source", domain.ErrDecryptionFailed)
		}
		rc, err := r.fetch(r.segs[i].cipherOffset, r.segs[i].cipherLen)
		if err != nil {
			return fmt.Errorf("failed to read encrypted object: %w", err)
		}
		src = rc
	}

	header := make([]byte, secretstream.StreamHeaderBytes)
	if _, err := io.ReadFull(src, header); err != nil {
		_ = src.Close()
		return fmt.Errorf("%w: failed to read segment header: %v", domain.ErrDecryptionFailed, err)
	}
	dec, err := secretstream.NewDecryptor(r.key, header)
	if err != nil {
		_ = src.Close()
		return fmt.Errorf("%w: %v", domain.ErrDecryptionFailed, err)
	}

	r.cipher = &limitedReadCloser{rc: src, r: io.LimitReader(src, r.segs[i].cipherLen)}
	r.dec = dec
	r.idx = i
	r.produced = 0
	r.final = false
	r.buf = nil
	r.pos = r.segs[i].plainOffset
	return nil
}

func (r *segmentReader) closeSegment() {
	if r.cipher != nil {
		_ = r.cipher.Close()
	}
	r.cipher, r.dec = nil, nil
	r.idx = -1
}

func (r *segmentReader) Close() error {
	var err error
	if r.cipher != nil {
		err = r.cipher.Close()
	}
	if r.initial != nil {
		if cerr := r.initial.Close(); cerr != nil && err == nil {
			err = cerr
		}
	}
	r.cipher, r.dec, r.initial = nil, nil, nil
	r.buf, r.chunk, r.scratch = nil, nil, nil
	r.idx = -1
	return err
}

// holds reports whether segment i contains plaintext position p.
func (r *segmentReader) holds(i int, p int64) bool {
	seg := r.segs[i]
	return p >= seg.plainOffset && p < seg.plainOffset+seg.plainLen
}

// segmentIndex is the segment containing plaintext position p, clamped to the
// last segment so a position at or past the end maps somewhere.
func (r *segmentReader) segmentIndex(p int64) int {
	i := sort.Search(len(r.segs), func(i int) bool {
		return r.segs[i].plainOffset+r.segs[i].plainLen > p
	})
	if i >= len(r.segs) {
		return len(r.segs) - 1
	}
	return i
}

// limitedReadCloser keeps reads inside one segment's ciphertext range so a
// corrupt chunk length cannot spill into the next segment.
type limitedReadCloser struct {
	rc io.ReadCloser
	r  io.Reader
}

func (l *limitedReadCloser) Read(p []byte) (int, error) { return l.r.Read(p) }

func (l *limitedReadCloser) Close() error { return l.rc.Close() }

// prefixedReadCloser replays bytes already consumed from rc.
func prefixedReadCloser(prefix []byte, rc io.ReadCloser) io.ReadCloser {
	return &limitedReadCloser{rc: rc, r: io.MultiReader(bytes.NewReader(prefix), rc)}
}
