package config

import (
	"log"
	"os"
	"runtime/debug"
	"strconv"
	"strings"
)

// containerMemoryLimitPaths are the cgroup files that report the container's
// memory cap, v2 first.
var containerMemoryLimitPaths = []string{
	"/sys/fs/cgroup/memory.max",
	"/sys/fs/cgroup/memory/memory.limit_in_bytes",
}

// ApplyMemoryLimit caps the Go heap just below the container's memory limit so
// the runtime collects garbage instead of letting the kernel OOM-kill the
// process. It is a no-op when GOMEMLIMIT is set (Go already applied it) or when
// the limit cannot be read (local dev on a host without cgroups).
func ApplyMemoryLimit() {
	if os.Getenv("GOMEMLIMIT") != "" {
		return
	}
	limit, ok := containerMemoryLimit()
	if !ok {
		return
	}
	// Leave a fifth of the limit for non-heap memory (stacks, I/O buffers, GC
	// metadata). Headroom is what keeps a 512 MiB box alive.
	budget := limit / 5 * 4
	debug.SetMemoryLimit(budget)
	log.Printf("Go heap limit set to %d MiB (container limit %d MiB)", budget>>20, limit>>20)
}

func containerMemoryLimit() (int64, bool) {
	for _, path := range containerMemoryLimitPaths {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		if limit, ok := parseMemoryLimit(data); ok {
			return limit, true
		}
	}
	return 0, false
}

// parseMemoryLimit reads a cgroup memory value, rejecting "max" and the
// effectively-unlimited sentinel cgroup v1 reports.
func parseMemoryLimit(raw []byte) (int64, bool) {
	value := strings.TrimSpace(string(raw))
	if value == "" || value == "max" {
		return 0, false
	}
	limit, err := strconv.ParseInt(value, 10, 64)
	if err != nil || limit <= 0 || limit > 1<<50 {
		return 0, false
	}
	return limit, true
}
