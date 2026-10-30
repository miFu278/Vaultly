package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"vaultly-be/internal/application/usecase"
	"vaultly-be/internal/infras/config"
	"vaultly-be/internal/infras/crypto"
	"vaultly-be/internal/infras/database"
	"vaultly-be/internal/infras/logging"
	"vaultly-be/internal/infras/media"
	"vaultly-be/internal/infras/repositories"
	"vaultly-be/internal/infras/storage"
	presentationHttp "vaultly-be/internal/presentation/http"
)

func main() {
	// 1. Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Cap the heap below the container limit so a memory spike triggers GC
	// instead of an OOM kill.
	config.ApplyMemoryLimit()

	// 2. Initialize database
	db, err := database.Connect(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Auto-run initial migrations if file exists
	if _, err := os.Stat("migrations/001_initial_schema.up.sql"); err == nil {
		if migErr := db.RunMigrations("migrations/001_initial_schema.up.sql"); migErr != nil {
			log.Printf("Migration notice: %v", migErr)
		}
	}

	// 3. Initialize Infrastructure Adapters
	var pool = db.Pool
	userRepo := repositories.NewUserRepository(pool)
	deviceRepo := repositories.NewDeviceRepository(pool)
	folderRepo := repositories.NewFolderRepository(pool)
	fileRepo := repositories.NewFileRepository(pool)
	pairingRepo := repositories.NewPairingRepository(pool)
	logRepo := repositories.NewLogRepository(pool)

	storageService, err := storage.NewS3StorageService(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize storage service: %v", err)
	}

	// Dedicated Libsodium Encryption Service with XChaCha20-Poly1305 & secretstream
	cryptoService := crypto.NewSodiumCryptoService()
	passwordHasher := crypto.NewBcryptHasher()
	tokenService := crypto.NewJWTTokenService(cfg.JWTSecret, cfg.JWTExpirationHours)
	thumbnailer := media.NewImageThumbnailer()

	// 4. Initialize Application Use Cases
	authUC := usecase.NewAuthUseCase(userRepo, passwordHasher, tokenService)
	deviceUC := usecase.NewDeviceUseCase(deviceRepo)
	folderUC := usecase.NewFolderUseCase(folderRepo)
	fileUC := usecase.NewFileUseCase(fileRepo, deviceRepo, storageService, cryptoService, thumbnailer)
	storageUC := usecase.NewStorageUseCase(userRepo, fileRepo)
	logUC := usecase.NewLogUseCase(logRepo)
	pairingUC := usecase.NewPairingUseCase(pairingRepo, deviceRepo, fileRepo, tokenService)

	// Request logs are mirrored into the database so the deployment can be read
	// from anywhere; the sink batches writes off the request path.
	var logSink *logging.Sink
	if cfg.LogToDB {
		logSink = logging.NewSink(logRepo, time.Duration(cfg.LogRetentionDays)*24*time.Hour)
		logSink.Start()
		log.Printf("request log mirrored to the database, kept for %d days", cfg.LogRetentionDays)
	}

	// 5. Initialize Presentation / HTTP Layer
	r := gin.New()
	presentationHttp.SetupRoutes(r, presentationHttp.RouterDependencies{
		AuthUseCase:      authUC,
		DeviceUseCase:    deviceUC,
		FolderUseCase:    folderUC,
		FileUseCase:      fileUC,
		StorageUseCase:   storageUC,
		LogUseCase:       logUC,
		AdminToken:       cfg.AdminToken,
		PairingUseCase:   pairingUC,
		TokenService:     tokenService,
		DeviceRepository: deviceRepo,
		MaxUploadBytes:   cfg.MaxUploadBytes(),
		LogSink:          logSink,
	})

	// 6. HTTP Server Setup with Graceful Shutdown
	// The global read/write timeouts stay short so a slow client cannot pin a
	// connection on ordinary requests. Large media transfers (video upload and
	// playback) opt out of them per request in the file handlers, and uploads
	// are bounded there by MAX_UPLOAD_MB instead.
	serverAddr := fmt.Sprintf(":%s", cfg.Port)
	srv := &http.Server{
		Addr:              serverAddr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Printf("Vaultly backend listening on http://localhost%s", serverAddr)
		log.Printf("Interactive API Docs available at http://localhost%s/docs", serverAddr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server listen error: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shut down
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down Vaultly backend server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
	if logSink != nil {
		logSink.Close()
	}

	log.Println("Server exited properly")
}
