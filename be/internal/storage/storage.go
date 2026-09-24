package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"vaultly-be/internal/config"
)

type StorageService struct {
	client        *s3.Client
	presignClient *s3.PresignClient
	bucketName    string
	expiration    time.Duration
}

func NewStorageService(cfg *config.Config) (*StorageService, error) {
	// If credentials are not set, return mock or stub service for local dev
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

	return &StorageService{
		client:        client,
		presignClient: presignClient,
		bucketName:    cfg.R2BucketName,
		expiration:    time.Duration(cfg.PresignedURLExpirationMinutes) * time.Minute,
	}, nil
}

// GeneratePresignedPutURL creates a presigned URL allowing the client to upload binary ciphertext directly to R2
func (s *StorageService) GeneratePresignedPutURL(ctx context.Context, objectKey string, contentType string, size int64) (string, error) {
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

// GeneratePresignedGetURL creates a presigned URL allowing the authorized client to download binary ciphertext directly from R2
func (s *StorageService) GeneratePresignedGetURL(ctx context.Context, objectKey string) (string, error) {
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

// DeleteObject deletes an object from R2
func (s *StorageService) DeleteObject(ctx context.Context, objectKey string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucketName),
		Key:    aws.String(objectKey),
	})
	if err != nil {
		return fmt.Errorf("failed to delete object from R2: %w", err)
	}
	return nil
}
