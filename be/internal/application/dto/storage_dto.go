package dto

// DefaultStorageQuotaBytes is what an account may store when the row carries no
// quota (older databases, or a user created before the column existed).
const DefaultStorageQuotaBytes int64 = 2 << 30 // 2 GiB

// StorageDTO is the account's vault usage against its quota.
type StorageDTO struct {
	UsedBytes   int64   `json:"used_bytes"`
	QuotaBytes  int64   `json:"quota_bytes"`
	PhotoBytes  int64   `json:"photo_bytes"`
	VideoBytes  int64   `json:"video_bytes"`
	FileCount   int64   `json:"file_count"`
	UsedPercent float64 `json:"used_percent"`
}
