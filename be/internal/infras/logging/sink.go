package logging

import (
	"context"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"vaultly-be/internal/domain/entity"
	"vaultly-be/internal/domain/repository"
)

const (
	// bufferSize bounds memory. When the database is slower than the traffic the
	// oldest entries are dropped instead of blocking a request.
	bufferSize = 1024
	// batchSize caps how many rows one flush writes.
	batchSize = 200
	// flushInterval is how long an entry normally waits before it is written.
	flushInterval = 2 * time.Second
	// writeTimeout keeps a slow database from stalling the flusher forever.
	writeTimeout = 10 * time.Second
)

// Sink records finished requests into storage without putting a database round
// trip on the request path.
type Sink struct {
	repo       repository.LogRepository
	retention  time.Duration
	purgeEvery time.Duration

	buffer    chan entity.AppLog
	done      chan struct{}
	closeOnce sync.Once
	wg        sync.WaitGroup
	dropped   atomic.Int64
}

func NewSink(repo repository.LogRepository, retention time.Duration) *Sink {
	if retention <= 0 {
		retention = 7 * 24 * time.Hour
	}
	return &Sink{
		repo:       repo,
		retention:  retention,
		purgeEvery: time.Hour,
		buffer:     make(chan entity.AppLog, bufferSize),
		done:       make(chan struct{}),
	}
}

// Start launches the flusher. Call Close on shutdown to write what is left.
func (s *Sink) Start() {
	s.wg.Add(1)
	go s.run()
}

// Append never blocks: logging must not be able to slow a request down, and a
// dropped line is better than a stalled response.
func (s *Sink) Append(entry entity.AppLog) {
	select {
	case s.buffer <- entry:
	default:
		s.dropped.Add(1)
	}
}

// Dropped reports how many entries were discarded because the buffer was full.
func (s *Sink) Dropped() int64 { return s.dropped.Load() }

// Close flushes what is buffered and stops the flusher. Safe to call twice,
// which happens when a caller closes the sink and a deferred close runs too.
func (s *Sink) Close() {
	s.closeOnce.Do(func() {
		close(s.done)
		s.wg.Wait()
		s.flush()
		if dropped := s.dropped.Load(); dropped > 0 {
			log.Printf("log sink dropped %d entries while the database was slow", dropped)
		}
	})
}

func (s *Sink) run() {
	defer s.wg.Done()

	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()
	purge := time.NewTicker(s.purgeEvery)
	defer purge.Stop()

	for {
		select {
		case <-s.done:
			return
		case <-ticker.C:
			s.flush()
		case <-purge.C:
			s.prune()
		}
	}
}

func (s *Sink) flush() {
	for {
		batch := make([]entity.AppLog, 0, batchSize)
		for len(batch) < batchSize {
			select {
			case entry := <-s.buffer:
				batch = append(batch, entry)
			default:
				if len(batch) == 0 {
					return
				}
				s.write(batch)
				return
			}
		}
		s.write(batch)
	}
}

func (s *Sink) write(batch []entity.AppLog) {
	ctx, cancel := context.WithTimeout(context.Background(), writeTimeout)
	defer cancel()
	if err := s.repo.InsertMany(ctx, batch); err != nil {
		// The nightly prune keeps the table bounded even if writes fail; a lost
		// batch is logged to stdout so the docker log still tells the story.
		log.Printf("log sink write failed (%d entries): %v", len(batch), err)
	}
}

func (s *Sink) prune() {
	ctx, cancel := context.WithTimeout(context.Background(), writeTimeout)
	defer cancel()
	removed, err := s.repo.DeleteOlderThan(ctx, time.Now().Add(-s.retention))
	if err != nil {
		log.Printf("log sink prune failed: %v", err)
		return
	}
	if removed > 0 {
		log.Printf("log sink removed %d entries older than %s", removed, s.retention)
	}
}
