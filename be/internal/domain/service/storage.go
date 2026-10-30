package service

import (
	"context"
	"io"
)

// ObjectStorage defines the contract for storing and retrieving encrypted blobs.
//
// Both directions stream: a media vault holds objects far larger than the memory
// of a small container, so nothing here may buffer a whole object.
type ObjectStorage interface {
	// GeneratePresignedPutURL generates a presigned URL for direct client PUT upload
	GeneratePresignedPutURL(ctx context.Context, objectKey string, contentType string, size int64) (string, error)

	// GeneratePresignedGetURL generates a presigned URL for direct client GET download
	GeneratePresignedGetURL(ctx context.Context, objectKey string) (string, error)

	// PutObjectReader stores size bytes read from r (a non-seekable stream is fine
	// because the caller knows the length).
	PutObjectReader(ctx context.Context, objectKey string, r io.Reader, size int64, contentType string) error

	// GetObjectReader streams an object and reports its exact stored size.
	GetObjectReader(ctx context.Context, objectKey string) (io.ReadCloser, int64, error)

	// GetObjectRange streams length bytes starting at offset, which is what makes
	// serving a byte range of an encrypted object cost one segment, not the file.
	GetObjectRange(ctx context.Context, objectKey string, offset, length int64) (io.ReadCloser, error)

	// DeleteObject deletes an object from storage
	DeleteObject(ctx context.Context, objectKey string) error

	// Probe reports whether the configured credentials may read objects from the
	// bucket. A deployment check, not a request path.
	Probe(ctx context.Context) error
}
