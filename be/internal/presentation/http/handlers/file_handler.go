package handlers

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"mime/multipart"
	"net/http"

	"github.com/danielgtaylor/huma/v2"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/application/dto"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain"
	"vaultly-be/internal/domain/service"
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

// FileIDInput is the path parameter shared by the single-file endpoints.
type FileIDInput struct {
	ID string `path:"id" doc:"File UUID"`
}

type FileOutput struct {
	Body dto.FileDTO
}

type EncryptedUploadInput struct {
	Body struct {
		FileName    string `json:"file_name" example:"vault_photo.jpg"`
		ImageBase64 string `json:"image_base64" example:"/9j/4AAQSkZJRgABAQEASABIAAD..." doc:"Base64-encoded raw media data (JPEG, PNG, WebP, GIF, MP4, WebM, AVI)"`
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
			// Without a device there is no wrapped key to hand out, and returning
			// the raw key is exactly what this endpoint used to leak.
			return nil, huma.Error403Forbidden(
				"download needs a paired device; use GET /files/{id}/view to read the media instead")
		}

		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		res, err := fileUC.DownloadFile(ctx, userID, targetDeviceID, fileID)
		if err != nil {
			if errors.Is(err, domain.ErrDeviceUnauthorized) {
				return nil, huma.Error403Forbidden(
					"this device has no key for the file; use GET /files/{id}/view instead")
			}
			return nil, huma.Error400BadRequest(err.Error())
		}

		return &DownloadFileOutput{Body: *res}, nil
	})

	// The list gave the app ids; this is the one endpoint that answers "what is
	// this file" without pulling the ciphertext.
	huma.Register(api, huma.Operation{
		OperationID: "getFile",
		Method:      http.MethodGet,
		Path:        "/files/{id}",
		Summary:     "Get one file's metadata",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *FileIDInput) (*FileOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}
		res, err := fileUC.GetFile(ctx, userID, fileID)
		if err != nil {
			return nil, huma.Error404NotFound(err.Error())
		}
		return &FileOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteFile",
		Method:      http.MethodDelete,
		Path:        "/files/{id}",
		Summary:     "Delete file metadata and storage ciphertext",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *FileIDInput) (*MessageOutput, error) {
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
		OperationID: "moveFileToFolder",
		Method:      http.MethodPatch,
		Path:        "/files/{id}/folder",
		Summary:     "Move file to a different folder (or remove from folder)",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct {
		ID   string `path:"id" doc:"File UUID"`
		Body struct {
			FolderID *uuid.UUID `json:"folder_id" doc:"Target folder UUID, or null to remove from folder"`
		}
	}) (*MessageOutput, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		if err := fileUC.MoveFileToFolder(ctx, userID, fileID, input.Body.FolderID); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "File moved successfully"
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "copyFileToFolder",
		Method:      http.MethodPost,
		Path:        "/files/{id}/copy",
		Summary:     "Copy file into another folder",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct {
		ID   string `path:"id" doc:"File UUID"`
		Body struct {
			FolderID *uuid.UUID `json:"folder_id" doc:"Target folder UUID"`
		}
	}) (*struct{ Body dto.FileDTO }, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		res, err := fileUC.CopyFileToFolder(ctx, userID, fileID, input.Body.FolderID)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		return &struct{ Body dto.FileDTO }{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "batchDeleteFiles",
		Method:      http.MethodPost,
		Path:        "/files/batch-delete",
		Summary:     "Delete multiple files in one batch",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct {
		Body struct {
			FileIDs []string `json:"file_ids" doc:"List of file UUIDs to delete"`
		}
	}) (*struct {
		Body struct {
			Deleted []string `json:"deleted"`
			Errors  []string `json:"errors"`
		}
	}, error) {
		userID, err := GetUserID(ctx)
		if err != nil {
			return nil, err
		}

		var uuids []uuid.UUID
		for _, s := range input.Body.FileIDs {
			if u, err := uuid.Parse(s); err == nil {
				uuids = append(uuids, u)
			}
		}

		deletedUUIDs, errMsgs := fileUC.BatchDeleteFiles(ctx, userID, uuids)
		var deletedStrs []string
		for _, u := range deletedUUIDs {
			deletedStrs = append(deletedStrs, u.String())
		}

		resp := &struct {
			Body struct {
				Deleted []string `json:"deleted"`
				Errors  []string `json:"errors"`
			}
		}{}
		resp.Body.Deleted = deletedStrs
		resp.Body.Errors = errMsgs
		return resp, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getThumbnail",
		Method:      http.MethodGet,
		Path:        "/files/{id}/thumbnail",
		Summary:     "Get presigned GET URL for fast gallery thumbnail",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *FileIDInput) (*DownloadFileOutput, error) {
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
			return nil, huma.Error400BadRequest("Invalid base64 media data")
		}

		deviceID := GetDeviceID(ctx)
		res, err := fileUC.UploadEncryptedImage(ctx, userID, deviceID, input.Body.FileName, rawBytes)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		return &EncryptedUploadOutput{Body: *res}, nil
	})
}

// RegisterFileGinRoutes adds multipart upload and decrypted media streaming routes to Gin.
// maxUploadBytes bounds a single upload body (0 falls back to defaultMaxUploadBytes).
func RegisterFileGinRoutes(r *gin.Engine, fileUC *usecase.FileUseCase, authMiddleware gin.HandlerFunc, maxUploadBytes int64) {
	filesGroup := r.Group("/files")
	filesGroup.Use(authMiddleware)
	{
		// Multipart Form Upload with XChaCha20-Poly1305 Encryption (supports multiple files & folder_id)
		filesGroup.POST("/upload", func(c *gin.Context) {
			// Bound the body and widen the read window BEFORE anything parses the
			// multipart form, otherwise the whole payload is already buffered and
			// an oversized video fails late (or not at all).
			limit := guardUploadBody(c, maxUploadBytes)

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

			var targetFolderID *uuid.UUID
			if fIDStr := c.PostForm("folder_id"); fIDStr != "" && fIDStr != "all" {
				if parsed, err := uuid.Parse(fIDStr); err == nil {
					targetFolderID = &parsed
				}
			}

			// Parse multipart form
			var fileHeaders []*multipart.FileHeader
			form, err := c.MultipartForm()
			if tooLarge(err) {
				c.JSON(http.StatusRequestEntityTooLarge, gin.H{
					"error": fmt.Sprintf("Tệp quá lớn, giới hạn %dMB mỗi tệp", limit>>20),
				})
				return
			}

			if err == nil && form != nil {
				if files, ok := form.File["files"]; ok {
					fileHeaders = append(fileHeaders, files...)
				}
				if files, ok := form.File["file"]; ok {
					fileHeaders = append(fileHeaders, files...)
				}
			}

			// Fallback to single FormFile
			if len(fileHeaders) == 0 {
				singleFile, sErr := c.FormFile("file")
				if sErr == nil && singleFile != nil {
					fileHeaders = append(fileHeaders, singleFile)
				}
			}

			if len(fileHeaders) == 0 {
				_ = c.Error(errors.New("no media part in the multipart body"))
				c.JSON(http.StatusBadRequest, gin.H{"error": "At least one media file ('file' or 'files') is required"})
				return
			}

			// One file at a time: each upload streams through a temp file, so a large
			// video never lands in memory. Uploading per file also bounds how much
			// temporary disk a single request can take.
			var uploaded []*dto.EncryptedImageUploadResponse
			var errMsgs []string

			for _, fileHeader := range fileHeaders {
				header := fileHeader
				f, fErr := header.Open()
				if fErr != nil {
					errMsgs = append(errMsgs, fErr.Error())
					continue
				}
				// The thumbnail pass re-opens the same spooled part, so the
				// plaintext is never held in memory.
				replay := func() (service.ReadSeekCloser, error) { return header.Open() }
				res, uErr := fileUC.UploadEncryptedStream(c.Request.Context(), userID, deviceID, header.Filename, f, replay, targetFolderID)
				_ = f.Close()
				if uErr != nil {
					errMsgs = append(errMsgs, uErr.Error())
					continue
				}
				uploaded = append(uploaded, res)
			}

			if len(uploaded) == 0 {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Upload failed", "details": errMsgs})
				return
			}

			if len(uploaded) == 1 {
				c.JSON(http.StatusOK, uploaded[0])
			} else {
				c.JSON(http.StatusOK, gin.H{
					"count": len(uploaded),
					"files": uploaded,
				})
			}
		})

		// Decrypt and stream media directly (for viewing in browser/app)
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

			// ?variant=thumb serves the small preview object for gallery tiles.
			var media *usecase.DecryptedMedia
			if c.Query("variant") == "thumb" {
				media, err = fileUC.OpenDecryptedThumbnail(c.Request.Context(), userID, deviceID, fileID)
			} else {
				media, err = fileUC.OpenDecryptedMedia(c.Request.Context(), userID, deviceID, fileID)
			}
			if err != nil {
				// The request log prints this reason, so a broken read names its
				// cause instead of a bare 400.
				_ = c.Error(err)
				status := http.StatusBadRequest
				if errors.Is(err, domain.ErrThumbnailNotFound) || errors.Is(err, domain.ErrFileNotFound) {
					status = http.StatusNotFound
				}
				c.JSON(status, gin.H{"error": err.Error()})
				return
			}
			defer media.Close()

			// A stable ETag lets the browser answer a repeat view with 304 instead of
			// paying the decrypt and the storage read again.
			variant := c.Query("variant")
			if variant == "" {
				variant = "full"
			}
			c.Writer.Header().Set("Etag", fmt.Sprintf(`"%s-%s"`, fileID, variant))

			serveMediaContent(c.Writer, c.Request, media.Content, media.ContentType)
		})
	}
}
