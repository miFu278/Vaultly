package service

import "context"

// ObjectStorage defines the contract for storing and retrieving encrypted blobs
type ObjectStorage interface {
	// GeneratePresignedPutURL generates a presigned URL for direct client PUT upload
	GeneratePresignedPutURL(ctx context.Context, objectKey string, contentType string, size int64) (string, error)

	// GeneratePresignedGetURL generates a presigned URL for direct client GET download
	GeneratePresignedGetURL(ctx context.Context, objectKey string) (string, error)

	// PutObject stores a binary payload directly in object storage
	PutObject(ctx context.Context, objectKey string, data []byte, contentType string) error

	// GetObject retrieves a binary payload directly from object storage
	GetObject(ctx context.Context, objectKey string) ([]byte, string, error)

	// DeleteObject deletes an object from storage
	DeleteObject(ctx context.Context, objectKey string) error
}
