package api

import (
	"context"
	"net/http"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humagin"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/auth"
	"vaultly-be/internal/config"
	"vaultly-be/internal/device"
	"vaultly-be/internal/file"
	"vaultly-be/internal/middleware"
	"vaultly-be/internal/models"
	"vaultly-be/internal/pairing"
)

type RouterDependencies struct {
	AuthService    *auth.AuthService
	DeviceService  *device.DeviceService
	FileService    *file.FileService
	PairingService *pairing.PairingService
	Config         *config.Config
}

type contextKey string

const (
	userIDKey   contextKey = "user_id"
	emailKey    contextKey = "email"
	deviceIDKey contextKey = "device_id"
)

// Helper to extract authenticated user from context
func getUserID(ctx context.Context) (uuid.UUID, error) {
	val := ctx.Value(userIDKey)
	if val == nil {
		return uuid.Nil, huma.Error401Unauthorized("Authentication required")
	}
	id, ok := val.(uuid.UUID)
	if !ok {
		return uuid.Nil, huma.Error401Unauthorized("Invalid authentication context")
	}
	return id, nil
}

// SetupRoutes registers all OpenAPI 3.1 & Huma endpoints on the Gin router
func SetupRoutes(r *gin.Engine, deps RouterDependencies) huma.API {
	humaConfig := huma.DefaultConfig("Vaultly Secure E2EE API", "1.0.0")
	humaConfig.Info.Description = "Cross-platform Zero-Knowledge E2EE Photo Vault API with multi-device authorization."
	humaConfig.DocsRenderer = huma.DocsRendererScalar

	// Security definition
	humaConfig.Components.SecuritySchemes = map[string]*huma.SecurityScheme{
		"bearerAuth": {
			Type:         "http",
			Scheme:       "bearer",
			BearerFormat: "JWT",
			Description:  "Enter your JWT Bearer token obtained from /auth/login or /auth/register",
		},
	}

	api := humagin.New(r, humaConfig)

	// Huma middleware for JWT and Device-ID context resolution
	api.UseMiddleware(func(ctx huma.Context, next func(huma.Context)) {
		authHeader := ctx.Header("Authorization")
		if authHeader != "" {
			claims, err := middleware.ValidateToken(authHeader, deps.Config.JWTSecret)
			if err == nil {
				ctx = huma.WithValue(ctx, userIDKey, claims.UserID)
				ctx = huma.WithValue(ctx, emailKey, claims.Email)
				if claims.DeviceID != nil {
					ctx = huma.WithValue(ctx, deviceIDKey, *claims.DeviceID)
				}
			}
		}

		if devHeader := ctx.Header("X-Device-ID"); devHeader != "" {
			if parsedDevID, err := uuid.Parse(devHeader); err == nil {
				ctx = huma.WithValue(ctx, deviceIDKey, parsedDevID)
			}
		}

		next(ctx)
	})

	registerSystemRoutes(api)
	registerAuthRoutes(api, deps.AuthService)
	registerDeviceRoutes(api, deps.DeviceService)
	registerFileRoutes(api, deps.FileService)
	registerPairingRoutes(api, deps.PairingService)

	return api
}

// System Routes
type HealthOutput struct {
	Body struct {
		Status    string `json:"status" example:"healthy"`
		Service   string `json:"service" example:"vaultly-backend"`
		Timestamp string `json:"timestamp"`
	}
}

func registerSystemRoutes(api huma.API) {
	huma.Register(api, huma.Operation{
		OperationID: "healthCheck",
		Method:      http.MethodGet,
		Path:        "/health",
		Summary:     "Health check",
		Description: "Check if the Vaultly backend service is healthy",
		Tags:        []string{"System"},
	}, func(ctx context.Context, input *struct{}) (*HealthOutput, error) {
		resp := &HealthOutput{}
		resp.Body.Status = "healthy"
		resp.Body.Service = "vaultly-backend"
		resp.Body.Timestamp = time.Now().Format(time.RFC3339)
		return resp, nil
	})
}

// Auth Routes
type AuthRegisterInput struct {
	Body models.RegisterRequest
}

type AuthLoginInput struct {
	Body models.LoginRequest
}

type AuthOutput struct {
	Body models.AuthResponse
}

type MeOutput struct {
	Body struct {
		UserID uuid.UUID `json:"user_id"`
		Email  string    `json:"email"`
	}
}

func registerAuthRoutes(api huma.API, authSvc *auth.AuthService) {
	huma.Register(api, huma.Operation{
		OperationID: "registerUser",
		Method:      http.MethodPost,
		Path:        "/auth/register",
		Summary:     "Register a new user account",
		Tags:        []string{"Auth"},
	}, func(ctx context.Context, input *AuthRegisterInput) (*AuthOutput, error) {
		res, err := authSvc.Register(ctx, input.Body.Email, input.Body.Password)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		return &AuthOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "loginUser",
		Method:      http.MethodPost,
		Path:        "/auth/login",
		Summary:     "Login with email & password",
		Tags:        []string{"Auth"},
	}, func(ctx context.Context, input *AuthLoginInput) (*AuthOutput, error) {
		res, err := authSvc.Login(ctx, input.Body.Email, input.Body.Password)
		if err != nil {
			return nil, huma.Error401Unauthorized(err.Error())
		}
		return &AuthOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getCurrentUser",
		Method:      http.MethodGet,
		Path:        "/auth/me",
		Summary:     "Get current authenticated user profile",
		Tags:        []string{"Auth"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*MeOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		email, _ := ctx.Value(emailKey).(string)

		resp := &MeOutput{}
		resp.Body.UserID = userID
		resp.Body.Email = email
		return resp, nil
	})
}

// Device Routes
type RegisterDeviceInput struct {
	Body models.RegisterDeviceRequest
}

type DeviceOutput struct {
	Body models.Device
}

type ListDevicesOutput struct {
	Body []models.Device
}

type RevokeDeviceInput struct {
	ID string `path:"id" doc:"Device UUID to revoke"`
}

type MessageOutput struct {
	Body struct {
		Message string `json:"message"`
	}
}

func registerDeviceRoutes(api huma.API, deviceSvc *device.DeviceService) {
	huma.Register(api, huma.Operation{
		OperationID: "registerDevice",
		Method:      http.MethodPost,
		Path:        "/devices/register",
		Summary:     "Register a new device public key",
		Tags:        []string{"Devices"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *RegisterDeviceInput) (*DeviceOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		dev, err := deviceSvc.RegisterDevice(ctx, userID, input.Body.Name, input.Body.PublicKey)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}
		return &DeviceOutput{Body: *dev}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "listDevices",
		Method:      http.MethodGet,
		Path:        "/devices",
		Summary:     "List all active authorized devices",
		Tags:        []string{"Devices"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *struct{}) (*ListDevicesOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		devices, err := deviceSvc.ListDevices(ctx, userID)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &ListDevicesOutput{Body: devices}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "revokeDevice",
		Method:      http.MethodPost,
		Path:        "/devices/{id}/revoke",
		Summary:     "Revoke an authorized device",
		Tags:        []string{"Devices"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *RevokeDeviceInput) (*MessageOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		deviceID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid device ID format")
		}

		if err := deviceSvc.RevokeDevice(ctx, userID, deviceID); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "Device revoked successfully"
		return resp, nil
	})
}

// File Routes
type InitUploadInput struct {
	Body models.InitUploadRequest
}

type InitUploadOutput struct {
	Body models.InitUploadResponse
}

type CompleteUploadInput struct {
	ID   string `path:"id" doc:"Pending file UUID"`
	Body models.CompleteUploadRequest
}

type ListFilesOutput struct {
	Body []models.File
}

type DownloadFileInput struct {
	ID       string `path:"id" doc:"File UUID to download"`
	DeviceID string `header:"X-Device-ID" doc:"UUID of requesting authorized device"`
}

type DownloadFileOutput struct {
	Body models.DownloadResponse
}

type DeleteFileInput struct {
	ID string `path:"id" doc:"File UUID to delete"`
}

func registerFileRoutes(api huma.API, fileSvc *file.FileService) {
	huma.Register(api, huma.Operation{
		OperationID: "initUpload",
		Method:      http.MethodPost,
		Path:        "/files/init",
		Summary:     "Initiate file upload and generate presigned PUT URL",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *InitUploadInput) (*InitUploadOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		res, err := fileSvc.InitUpload(ctx, userID, input.Body)
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
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		if err := fileSvc.CompleteUpload(ctx, userID, fileID, input.Body); err != nil {
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
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		files, err := fileSvc.ListFiles(ctx, userID)
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
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}

		// Resolve device id from header or token
		var targetDeviceID uuid.UUID
		if input.DeviceID != "" {
			parsed, err := uuid.Parse(input.DeviceID)
			if err != nil {
				return nil, huma.Error400BadRequest("Invalid X-Device-ID header")
			}
			targetDeviceID = parsed
		} else if devVal := ctx.Value(deviceIDKey); devVal != nil {
			targetDeviceID = devVal.(uuid.UUID)
		} else {
			return nil, huma.Error400BadRequest("X-Device-ID header or device token claim is required")
		}

		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		res, err := fileSvc.DownloadFile(ctx, userID, targetDeviceID, fileID)
		if err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		return &DownloadFileOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "deleteFile",
		Method:      http.MethodDelete,
		Path:        "/files/{id}",
		Summary:     "Delete file metadata and R2 ciphertext",
		Tags:        []string{"Files"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *DeleteFileInput) (*MessageOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}
		fileID, err := uuid.Parse(input.ID)
		if err != nil {
			return nil, huma.Error400BadRequest("Invalid file ID format")
		}

		if err := fileSvc.DeleteFile(ctx, userID, fileID); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "File deleted successfully"
		return resp, nil
	})
}

// Pairing Routes
type PairingStartInput struct {
	Body models.PairingStartRequest
}

type PairingStartOutput struct {
	Body models.PairingStartResponse
}

type PairingStatusInput struct {
	Token string `path:"token" doc:"32-byte hex pairing token"`
}

type PairingStatusOutput struct {
	Body map[string]any
}

type PairingCompleteInput struct {
	Body models.PairingCompleteRequest
}

func registerPairingRoutes(api huma.API, pairingSvc *pairing.PairingService) {
	huma.Register(api, huma.Operation{
		OperationID: "startPairing",
		Method:      http.MethodPost,
		Path:        "/pairing/start",
		Summary:     "Start device pairing session for new device",
		Tags:        []string{"Pairing"},
	}, func(ctx context.Context, input *PairingStartInput) (*PairingStartOutput, error) {
		res, err := pairingSvc.StartPairing(ctx, input.Body.PublicKey, input.Body.DeviceName)
		if err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return &PairingStartOutput{Body: *res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "getPairingStatus",
		Method:      http.MethodGet,
		Path:        "/pairing/{token}",
		Summary:     "Poll pairing status (called by new device)",
		Tags:        []string{"Pairing"},
	}, func(ctx context.Context, input *PairingStatusInput) (*PairingStatusOutput, error) {
		res, err := pairingSvc.GetPairingStatus(ctx, input.Token)
		if err != nil {
			return nil, huma.Error404NotFound(err.Error())
		}
		return &PairingStatusOutput{Body: res}, nil
	})

	huma.Register(api, huma.Operation{
		OperationID: "completePairing",
		Method:      http.MethodPost,
		Path:        "/pairing/complete",
		Summary:     "Approve pairing and submit wrapped keys for new device",
		Tags:        []string{"Pairing"},
		Security:    []map[string][]string{{"bearerAuth": {}}},
	}, func(ctx context.Context, input *PairingCompleteInput) (*MessageOutput, error) {
		userID, err := getUserID(ctx)
		if err != nil {
			return nil, err
		}

		if err := pairingSvc.CompletePairing(ctx, userID, input.Body); err != nil {
			return nil, huma.Error400BadRequest(err.Error())
		}

		resp := &MessageOutput{}
		resp.Body.Message = "Pairing completed and device authorized successfully"
		return resp, nil
	})
}
