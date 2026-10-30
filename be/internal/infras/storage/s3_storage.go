package storage

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/smithy-go"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/infras/config"
)

type S3StorageService struct {
	client        *s3.Client
	presignClient *s3.PresignClient
	bucketName    string
	expiration    time.Duration
	// In-memory fallback for local dev when R2 is not configured
	memMu    sync.RWMutex
	memData  map[string][]byte
	memBytes int64
}

// memStoreBudget caps the development fallback store. Without it a deployment
// that forgets the R2 credentials would grow the heap until the container is
// OOM-killed; with it the upload fails with a clear error instead.
const memStoreBudget int64 = 64 << 20

func newMemoryStorage(cfg *config.Config) *S3StorageService {
	log.Printf("WARNING: R2 credentials are not configured; using in-memory storage (max %d MiB, data is lost on restart)", memStoreBudget>>20)
	return &S3StorageService{
		bucketName: cfg.R2BucketName,
		expiration: time.Duration(cfg.PresignedURLExpirationMinutes) * time.Minute,
		memData:    make(map[string][]byte),
	}
}

func NewS3StorageService(cfg *config.Config) (service.ObjectStorage, error) {
	// If credentials are not set, return in-memory storage for local dev / testing
	if cfg.R2AccessKeyID == "" || cfg.R2SecretAccessKey == "" {
		return newMemoryStorage(cfg), nil
	}

	endpoint := cfg.R2Endpoint
	if endpoint == "" && cfg.R2AccountID != "" {
		endpoint = fmt.Sprintf("https://%s.r2.cloudflarestorage.com", cfg.R2AccountID)
	}

	customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
		if endpoint != "" {
			return aws.Endpoint{
				URL:               endpoint,
				SigningRegion:     "auto",
				HostnameImmutable: true,
			}, nil
		}
		return aws.Endpoint{}, &aws.EndpointNotFoundError{}
	})

	awsCfg, err := awsconfig.LoadDefaultConfig(context.TODO(),
		awsconfig.WithEndpointResolverWithOptions(customResolver),
		awsconfig.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(
			cfg.R2AccessKeyID,
			cfg.R2SecretAccessKey,
			"",
		)),
		awsconfig.WithRegion("auto"),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS/R2 configuration: %w", err)
	}

	client := s3.NewFromConfig(awsCfg, func(o *s3.Options) {
		o.UsePathStyle = true
	})

	presignClient := s3.NewPresignClient(client)

	return &S3StorageService{
		client:        client,
		presignClient: presignClient,
		bucketName:    cfg.R2BucketName,
		expiration:    time.Duration(cfg.PresignedURLExpirationMinutes) * time.Minute,
		memData:       make(map[string][]byte),
	}, nil
}

func (s *S3StorageService) GeneratePresignedPutURL(ctx context.Context, objectKey string, contentType string, size int64) (string, error) {
	if s.presignClient == nil {
		return fmt.Sprintf("http://localhost:8080/mock-storage/put/%s", objectKey), nil
	}

	input := &s3.PutObjectInput{
		Bucket:        aws.String(s.bucketName),
		Key:           aws.String(objectKey),
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(size),
	}

	req, err := s.presignClient.PresignPutObject(ctx, input, s3.WithPresignExpires(s.expiration))
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned PUT url: %w", err)
	}

	return req.URL, nil
}

func (s *S3StorageService) GeneratePresignedGetURL(ctx context.Context, objectKey string) (string, error) {
	if s.presignClient == nil {
		return fmt.Sprintf("http://localhost:8080/mock-storage/get/%s", objectKey), nil
	}

	input := &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(objectKey),
	}

	req, err := s.presignClient.PresignGetObject(ctx, input, s3.WithPresignExpires(s.expiration))
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned GET url: %w", err)
	}

	return req.URL, nil
}

func (s *S3StorageService) PutObjectReader(ctx context.Context, objectKey string, r io.Reader, size int64, contentType string) error {
	if s.client == nil {
		return s.memPut(objectKey, r, size)
	}

	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(s.bucketName),
		Key:           aws.String(objectKey),
		Body:          r,
		ContentLength: aws.Int64(size),
		ContentType:   aws.String(contentType),
	})
	if err != nil {
		return fmt.Errorf("failed to put object to storage: %w", err)
	}
	return nil
}

// accessDeniedHint turns the raw S3 403 into something an operator can act on.
// Cloudflare answers AccessDenied, not NotFound, when the API token does not
// cover the bucket, which reads like a code failure otherwise.
func accessDeniedHint(bucket string, err error) error {
	var apiErr smithy.APIError
	if errors.As(err, &apiErr) && apiErr.ErrorCode() == "AccessDenied" {
		return fmt.Errorf("%w: bucket %q refused the request; give the R2 API token Object Read (and Object Write) on that exact bucket", err, bucket)
	}
	return err
}

// Probe asks for a key that does not exist. A not-found answer proves the request
// was authorized; AccessDenied proves the token cannot read this bucket at all.
func (s *S3StorageService) Probe(ctx context.Context) error {
	if s.client == nil {
		return nil
	}

	_, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String("__vaultly_probe__"),
	})
	if err == nil {
		return nil
	}

	var apiErr smithy.APIError
	if errors.As(err, &apiErr) {
		switch apiErr.ErrorCode() {
		case "NoSuchKey", "NotFound":
			return nil
		}
	}
	return accessDeniedHint(s.bucketName, err)
}

func (s *S3StorageService) GetObjectReader(ctx context.Context, objectKey string) (io.ReadCloser, int64, error) {
	if s.client == nil {
		s.memMu.RLock()
		data, exists := s.memData[objectKey]
		s.memMu.RUnlock()
		if !exists {
			return nil, 0, fmt.Errorf("object not found: %s", objectKey)
		}
		// Copy so the returned reader stays valid if the object is deleted, and
		// so the caller does not hold the lock for the whole response.
		buf := make([]byte, len(data))
		copy(buf, data)
		return io.NopCloser(bytes.NewReader(buf)), int64(len(buf)), nil
	}

	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(objectKey),
	})
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get object from storage: %w", accessDeniedHint(s.bucketName, err))
	}

	size := int64(0)
	if out.ContentLength != nil {
		size = *out.ContentLength
	}
	return out.Body, size, nil
}

func (s *S3StorageService) GetObjectRange(ctx context.Context, objectKey string, offset, length int64) (io.ReadCloser, error) {
	if s.client == nil {
		s.memMu.RLock()
		data, exists := s.memData[objectKey]
		s.memMu.RUnlock()
		if !exists {
			return nil, fmt.Errorf("object not found: %s", objectKey)
		}
		if offset < 0 || offset > int64(len(data)) {
			return nil, fmt.Errorf("range start %d out of bounds for %s", offset, objectKey)
		}
		end := offset + length
		if end > int64(len(data)) {
			end = int64(len(data))
		}
		buf := make([]byte, end-offset)
		copy(buf, data[offset:end])
		return io.NopCloser(bytes.NewReader(buf)), nil
	}

	if length <= 0 {
		return nil, fmt.Errorf("invalid range length %d for %s", length, objectKey)
	}
	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(objectKey),
		Range:  aws.String(fmt.Sprintf("bytes=%d-%d", offset, offset+length-1)),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to read object range from storage: %w", accessDeniedHint(s.bucketName, err))
	}
	return out.Body, nil
}

// memPut buffers a payload in the development fallback store, refusing to grow
// past memStoreBudget.
func (s *S3StorageService) memPut(objectKey string, r io.Reader, size int64) error {
	s.memMu.Lock()
	defer s.memMu.Unlock()

	if s.memBytes+size > memStoreBudget {
		return fmt.Errorf("in-memory storage limit (%d MiB) reached, configure R2 credentials", memStoreBudget>>20)
	}
	data, err := io.ReadAll(r)
	if err != nil {
		return fmt.Errorf("failed to read upload body: %w", err)
	}
	if old, ok := s.memData[objectKey]; ok {
		s.memBytes -= int64(len(old))
	}
	s.memData[objectKey] = data
	s.memBytes += int64(len(data))
	return nil
}

func (s *S3StorageService) DeleteObject(ctx context.Context, objectKey string) error {
	if s.client == nil {
		s.memMu.Lock()
		defer s.memMu.Unlock()
		if old, ok := s.memData[objectKey]; ok {
			s.memBytes -= int64(len(old))
		}
		delete(s.memData, objectKey)
		return nil
	}

	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(objectKey),
	})
	if err != nil {
		return fmt.Errorf("failed to delete object from storage: %w", err)
	}
	return nil
}
