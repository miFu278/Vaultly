package handlers

import (
	"context"
	"encoding/base64"
	"io"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
)

type InitUploadInput struct {
	Body dto.InitUploadRequest
}

type InitUploadOutput struct {
	Body dto.InitUploadResponse
}

type CompleteUploadInput struct {
	ID   string `path:"id" doc:"Pending file UUID"`
	Body dto.CompleteUploadRequest
}

type ListFilesOutput struct {
	Body []dto.FileDTO
}

type DownloadFileInput struct {
	ID       string `path:"id" doc:"File UUID to download"`
	DeviceID string `header:"X-Device-ID" doc:"UUID of requesting authorized device (optional if in JWT)"`
}

type DownloadFileOutput struct {
	Body dto.DownloadResponse
}

type DeleteFileInput struct {
	ID string `path:"id" doc:"File UUID to delete"`
}

type EncryptedUploadInput struct {
	Body struct {
		FileName  string `json:"file_name" example:"vault_photo.jpg"`
		ImageBase64 string `json:"image_base64" example:"/9j/4AAQSkZJRgABAQEASABIAAD..." doc:"Base64-encoded raw image data (JPEG, PNG, WebP, GIF)"`
	}
}

type EncryptedUploadOutput struct {
	Body dto.EncryptedImageUploadResponse
}

func RegisterFileRoutes(api huma.API, fileUC *usecase.FileUseCase) {
	huma.Register(api, huma.Operation{
		OperationID: "initUpload",
		Method:      http.MethodPost,
		Path:        "/files/init",
		Summary:     "Initiate file upload and generate presigned PUT URL",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *InitUploadInput) (*InitUploadOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		res, err := fileUC.InitUpload(ctx, userID, input.Body)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &InitUploadOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "completeUpload",
		Method:      http.MethodPost,
		Path:        "/files/{id}/complete",
		Summary:     "Mark file ready and submit wrapped keys per device",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *CompleteUploadInput) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		if err := fileUC.CompleteUpload(ctx, userID, fileID, input.Body); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "Upload completed successfully"
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listFiles",
		Method:      http.MethodGet,
		Path:        "/files",
		Summary:     "List all ready files for user",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*ListFilesOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		files, err := fileUC.ListFiles(ctx, userID)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &ListFilesOutput{Body: files}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "downloadFile",
		Method:      http.MethodGet,
		Path:        "/files/{id}/download",
		Summary:     "Get presigned GET URL & wrapped key for device",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *DownloadFileInput) (*DownloadFileOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}

		var targetDeviceID uuid.UUID
		if input.DeviceID != "" {
			parsed, err := uuid.Parse(input.DeviceID)
			if err != nil {
				return nil, huma.Error400BadRequest("Invalid X-Device-ID header")
			}
			targetDeviceID = parsed
		} else if devVal := GetDeviceID(ctx); devVal != nil {
			targetDeviceID = *devVal
		} else {
			return nil, huma.Error400BadRequest("X-Device-ID header or device token claim is required")
		}

		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		res, err := fileUC.DownloadFile(ctx, userID, targetDeviceID, fileID)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		return &DownloadFileOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteFile",
		Method:      http.MethodDelete,
		Path:        "/files/{id}",
		Summary:     "Delete file metadata and storage ciphertext",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *DeleteFileInput) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		if err := fileUC.DeleteFile(ctx, userID, fileID); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "File deleted successfully"
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getThumbnail",
		Method:      http.MethodGet,
		Path:        "/files/{id}/thumbnail",
		Summary:     "Get presigned GET URL for fast gallery thumbnail",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *DeleteFileInput) (*DownloadFileOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		res, err := fileUC.GetThumbnail(ctx, userID, fileID)
		if err != nil {
			return nil, huma.Error404NotFound(err.Error())
		}

		return &DownloadFileOutput{
			Body: dto.DownloadResponse{
				PresignedURL: res.PresignedURL,
			},
		}, nil
	})

	// Direct encrypted image upload endpoint (Base64 JSON for OpenAPI / Scalar test requests)
	huma.Register(api, huma.Operation{
		OperationID: "uploadEncryptedImage",
		Method:      http.MethodPost,
		Path:        "/files/encrypt-upload",
		Summary:     "Upload raw image, chunk-encrypt with XChaCha20-Poly1305 (crypto_secretstream) and store",
		Description: "Accepts base64-encoded image (JPEG, PNG, WebP, GIF), validates format, encrypts via libsodium crypto_secretstream_xchacha20poly1305, wraps key via crypto_box_seal, and saves ciphertext to storage.",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *EncryptedUploadInput) (*EncryptedUploadOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}

		rawBytes, err := base64.StdEncoding.DecodeString(input.Body.ImageBase64)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid base64 image data")
		}

		deviceID := GetDeviceID(ctx)
		res, err := fileUC.UploadEncryptedImage(ctx, userID, deviceID, input.Body.FileName, rawBytes)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		return &EncryptedUploadOutput{Body: *res}, nil
	})
}

// RegisterFileGinRoutes adds multipart upload and decrypted image streaming routes to Gin
func RegisterFileGinRoutes(r *gin.Engine, fileUC *usecase.FileUseCase, authMiddleware gin.HandlerFunc) {
	filesGroup := r.Group("/files")
	filesGroup.Use(authMiddleware)
	{
		// Multipart Form Image Upload with XChaCha20-Poly1305 Encryption
		filesGroup.POST("/upload", func(c *gin.Context) {
			userIDVal, exists := c.Get("user_id")
			if !exists {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
				return
			}
			userID := userIDVal.(uuid.UUID)

			var deviceID *uuid.UUID
			if devVal, ok := c.Get("device_id"); ok {
				d := devVal.(uuid.UUID)
				deviceID = &d
			}

			fileHeader, err := c.FormFile("file")
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Multipart form 'file' is required"})
				return
			}

			file, err := fileHeader.Open()
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read uploaded file"})
				return
			}
			defer file.Close()

			rawBytes, err := io.ReadAll(file)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file bytes"})
				return
			}

			res, err := fileUC.UploadEncryptedImage(c.Request.Context(), userID, deviceID, fileHeader.Filename, rawBytes)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			c.JSON(http.StatusOK, res)
		})

		// Decrypt and stream image directly (for viewing in browser/app)
		filesGroup.GET("/:id/view", func(c *gin.Context) {
			userIDVal, exists := c.Get("user_id")
			if !exists {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
				return
			}
			userID := userIDVal.(uuid.UUID)

			var deviceID *uuid.UUID
			if devVal, ok := c.Get("device_id"); ok {
				d := devVal.(uuid.UUID)
				deviceID = &d
			}

			fileIDStr := c.Param("id")
			fileID, err := uuid.Parse(fileIDStr)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
				return
			}

			decryptedBytes, contentType, err := fileUC.DownloadAndDecryptImage(c.Request.Context(), userID, deviceID, fileID)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}

			c.Data(http.StatusOK, contentType, decryptedBytes)
		})
	}
}
