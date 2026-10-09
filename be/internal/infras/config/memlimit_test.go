package config

import "testing"

func TestParseMemoryLimit(t *testing.T) {
	tests := []struct {
		name   string
		raw    string
		want   int64
		wantOK bool
	}{
		{name: "cgroup v2 limit", raw: "536870912\n", want: 536870912, wantOK: true},
		{name: "cgroup v1 limit", raw: "1073741824", want: 1073741824, wantOK: true},
		{name: "cgroup v2 unlimited", raw: "max", wantOK: false},
		// cgroup v1 reports "unlimited" as a huge sentinel, not "max".
		{name: "cgroup v1 unlimited", raw: "9223372036854771712", wantOK: false},
		{name: "empty", raw: "  ", wantOK: false},
		{name: "garbage", raw: "not-a-number", wantOK: false},
		{name: "zero", raw: "0", wantOK: false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, ok := parseMemoryLimit([]byte(tc.raw))
			if ok != tc.wantOK {
				t.Fatalf("ok = %v, want %v", ok, tc.wantOK)
			}
			if got != tc.want {
				t.Fatalf("limit = %d, want %d", got, tc.want)
			}
		})
	}
}
