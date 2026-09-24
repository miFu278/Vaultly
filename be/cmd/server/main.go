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
	"vaultly-be/internal/api"
	"vaultly-be/internal/auth"
	"vaultly-be/internal/config"
	"vaultly-be/internal/database"
	"vaultly-be/internal/device"
	"vaultly-be/internal/file"
	"vaultly-be/internal/middleware"
	"vaultly-be/internal/pairing"
	"vaultly-be/internal/storage"
)

func main() {
	// Load configuration
	cfg, err := config.LoadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Initialize database
	db, err := database.Connect(cfg)
	if err != nil {
		log.Printf("Warning: Failed to connect to database: %v. Running in limited mode.", err)
	} else {
		defer db.Close()
		// Auto-run initial migrations if file exists
		if _, err := os.Stat("migrations/001_initial_schema.up.sql"); err == nil {
			if migErr := db.RunMigrations("migrations/001_initial_schema.up.sql"); migErr != nil {
				log.Printf("Migration notice: %v", migErr)
			}
		}
	}

	// Initialize Cloudflare R2 / S3 storage
	storageService, err := storage.NewStorageService(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize storage service: %v", err)
	}

	// Initialize domain services
	authService := auth.NewAuthService(db, cfg)
	deviceService := device.NewDeviceService(db)
	fileService := file.NewFileService(db, storageService)
	pairingService := pairing.NewPairingService(db, cfg)

	// Setup Gin router
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(middleware.CORSMiddleware())

	// Register OpenAPI 3.1 & Huma routes (interactive docs at /docs)
	api.SetupRoutes(r, api.RouterDependencies{
		AuthService:    authService,
		DeviceService:  deviceService,
		FileService:    fileService,
		PairingService: pairingService,
		Config:         cfg,
	})

	// Server setup with graceful shutdown
	serverAddr := fmt.Sprintf(":%s", cfg.Port)
	srv := &http.Server{
		Addr:         serverAddr,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("Vaultly backend listening on http://localhost%s", serverAddr)
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

	log.Println("Server exited properly")
}
