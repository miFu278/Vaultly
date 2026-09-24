package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/infras/config"
)

type S3StorageService struct {
	client        *s3.Client
	presignClient *s3.PresignClient
	bucketName    string
	expiration    time.Duration
	// In-memory fallback for local dev when R2 is not configured
	memMu   sync.RWMutex
	memData map[string][]byte
	memType map[string]string
}

func NewS3StorageService(cfg *config.Config) (service.ObjectStorage, error) {
	// If credentials are not set, return in-memory storage for local dev / testing
	if cfg.R2AccessKeyID == "" || cfg.R2SecretAccessKey == "" {
		return &S3StorageService{
			bucketName: cfg.R2BucketName,
			expiration: time.Duration(cfg.PresignedURLExpirationMinutes) * time.Minute,
			memData:    make(map[string][]byte),
			memType:    make(map[string]string),
		}, nil
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
		memType:       make(map[string]string),
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

func (s *S3StorageService) PutObject(ctx context.Context, objectKey string, data []byte, contentType string) error {
	if s.client == nil {
		s.memMu.Lock()
		defer s.memMu.Unlock()
		s.memData[objectKey] = data
		s.memType[objectKey] = contentType
		return nil
	}

	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(s.bucketName),
		Key:           aws.String(objectKey),
		Body:          bytes.NewReader(data),
		ContentLength: aws.Int64(int64(len(data))),
		ContentType:   aws.String(contentType),
	})
	if err != nil {
		return fmt.Errorf("failed to put object to storage: %w", err)
	}
	return nil
}

func (s *S3StorageService) GetObject(ctx context.Context, objectKey string) ([]byte, string, error) {
	if s.client == nil {
		s.memMu.RLock()
		defer s.memMu.RUnlock()
		data, exists := s.memData[objectKey]
		if !exists {
			return nil, "", fmt.Errorf("object not found: %s", objectKey)
		}
		return data, s.memType[objectKey], nil
	}

	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(objectKey),
	})
	if err != nil {
		return nil, "", fmt.Errorf("failed to get object from storage: %w", err)
	}
	defer out.Body.Close()

	data, err := io.ReadAll(out.Body)
	if err != nil {
		return nil, "", fmt.Errorf("failed to read object body: %w", err)
	}

	contentType := "application/octet-stream"
	if out.ContentType != nil {
		contentType = *out.ContentType
	}

	return data, contentType, nil
}

func (s *S3StorageService) DeleteObject(ctx context.Context, objectKey string) error {
	if s.client == nil {
		s.memMu.Lock()
		defer s.memMu.Unlock()
		delete(s.memData, objectKey)
		delete(s.memType, objectKey)
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
