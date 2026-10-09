package http

import (
	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humagin"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/domain/service"
	"vaultly-be/internal/presentation/http/handlers"
	"vaultly-be/internal/presentation/http/middleware"
)

type RouterDependencies struct {
	AuthUseCase    *usecase.AuthUseCase
	DeviceUseCase  *usecase.DeviceUseCase
	FolderUseCase  *usecase.FolderUseCase
	FileUseCase    *usecase.FileUseCase
	PairingUseCase *usecase.PairingUseCase
	TokenService   service.TokenService
	// MaxUploadBytes caps a single upload body (0 = handler default).
	MaxUploadBytes int64
}

// maxJSONBodyBytes caps request bodies on the JSON endpoints (uploads set their
// own, larger cap).
const maxJSONBodyBytes int64 = 8 << 20

// multipartMemoryBytes is how much of a multipart upload gin keeps in RAM; the
// rest is spooled to temp files instead of the heap.
const multipartMemoryBytes int64 = 4 << 20

func SetupRoutes(r *gin.Engine, deps RouterDependencies) huma.API {
	r.MaxMultipartMemory = multipartMemoryBytes

	// Setup standard Gin middleware
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(middleware.BodyLimitMiddleware(maxJSONBodyBytes))
	r.Use(middleware.CORSMiddleware())

	// Configure Huma OpenAPI 3.1 & Scalar interactive docs
	humaConfig := huma.DefaultConfig("Vaultly Secure E2EE Photo Vault API", "2.0.0")
	humaConfig.Info.Description = "Cross-platform Zero-Knowledge E2EE Photo Vault API with libsodium XChaCha20-Poly1305 (crypto_secretstream) chunked encryption and crypto_box_seal multi-device key authorization."
	humaConfig.DocsRenderer = huma.DocsRendererScalar

	// Define Security Scheme
	humaConfig.Components.SecuritySchemes = map[string]*huma.SecurityScheme{
		"bearerAuth": {
			Type:         "http",
			Scheme:       "bearer",
			BearerFormat: "JWT",
			Description:  "Enter your JWT Bearer token obtained from /auth/login or /auth/register",
		},
	}

	api := humagin.New(r, humaConfig)

	// Huma authentication middleware
	api.UseMiddleware(func(ctx huma.Context, next func(huma.Context)) {
		authHeader := ctx.Header("Authorization")
		if authHeader == "" {
			if qToken := ctx.Query("token"); qToken != "" {
				authHeader = "Bearer " + qToken
			}
		}
		if authHeader != "" {
			claims, err := deps.TokenService.Validate(authHeader)
			if err == nil {
				ctx = huma.WithValue(ctx, handlers.UserIDKey, claims.UserID)
				ctx = huma.WithValue(ctx, handlers.EmailKey, claims.Email)
				if claims.DeviceID != nil {
					ctx = huma.WithValue(ctx, handlers.DeviceIDKey, *claims.DeviceID)
				}
			}
		}

		if devHeader := ctx.Header("X-Device-ID"); devHeader != "" {
			if parsedDevID, err := uuid.Parse(devHeader); err == nil {
				ctx = huma.WithValue(ctx, handlers.DeviceIDKey, parsedDevID)
			}
		}

		next(ctx)
	})

	// Register Huma routes
	handlers.RegisterSystemRoutes(api)
	handlers.RegisterAuthRoutes(api, deps.AuthUseCase)
	handlers.RegisterDeviceRoutes(api, deps.DeviceUseCase)
	handlers.RegisterFolderRoutes(api, deps.FolderUseCase, deps.FileUseCase)
	handlers.RegisterFileRoutes(api, deps.FileUseCase)
	handlers.RegisterPairingRoutes(api, deps.PairingUseCase)

	// Register Gin-specific routes (multipart image upload & decrypted stream view)
	authMW := middleware.AuthMiddleware(deps.TokenService)
	handlers.RegisterFileGinRoutes(r, deps.FileUseCase, authMW, deps.MaxUploadBytes)

	return api
}
