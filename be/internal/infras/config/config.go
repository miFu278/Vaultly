package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// defaultJWTSecret is the development fallback. Production refuses it (see
// validate) because every deployment would share the same signing key.
const defaultJWTSecret = "default_secret_key_change_me"

type Config struct {
	Port                          string
	Env                           string
	DatabaseURI                   string
	DBHost                        string
	DBPort                        string
	DBUser                        string
	DBPassword                    string
	DBName                        string
	DBSSLMode                     string
	JWTSecret                     string
	JWTExpirationHours            int
	R2AccountID                   string
	R2AccessKeyID                 string
	R2SecretAccessKey             string
	R2BucketName                  string
	R2Endpoint                    string
	PresignedURLExpirationMinutes int
	MaxUploadMB                   int
	// AdminToken guards GET /admin/logs. Empty means the route is not served.
	AdminToken string
	// LogToDB mirrors request logs into the database so they can be read from
	// anywhere instead of only from the host's docker log.
	LogToDB          bool
	LogRetentionDays int
}

func LoadConfig() (*Config, error) {
	// Load .env file if exists, ignore error if not found in production
	_ = godotenv.Load()

	jwtHours, _ := strconv.Atoi(getEnv("JWT_EXPIRATION_HOURS", "720"))
	presignedMinutes, _ := strconv.Atoi(getEnv("PRESIGNED_URL_EXPIRATION_MINUTES", "15"))
	maxUploadMB, _ := strconv.Atoi(getEnv("MAX_UPLOAD_MB", "512"))
	logDays, _ := strconv.Atoi(getEnv("LOG_RETENTION_DAYS", "7"))

	cfg := &Config{
		Port:                          getEnv("PORT", "8080"),
		Env:                           getEnv("ENV", "development"),
		DBHost:                        getEnv("DB_HOST", "localhost"),
		DBPort:                        getEnv("DB_PORT", "5432"),
		DBUser:                        getEnv("DB_USER", "vaultly"),
		DBPassword:                    getEnv("DB_PASSWORD", "vaultly_secret"),
		DBName:                        getEnv("DB_NAME", "vaultly"),
		DBSSLMode:                     getEnv("DB_SSLMODE", "disable"),
		JWTSecret:                     getEnv("JWT_SECRET", defaultJWTSecret),
		JWTExpirationHours:            jwtHours,
		R2AccountID:                   getEnv("R2_ACCOUNT_ID", ""),
		R2AccessKeyID:                 getEnv("R2_ACCESS_KEY_ID", ""),
		R2SecretAccessKey:             getEnv("R2_SECRET_ACCESS_KEY", ""),
		R2BucketName:                  getEnv("R2_BUCKET_NAME", "vaultly-storage"),
		R2Endpoint:                    getEnv("R2_ENDPOINT", ""),
		PresignedURLExpirationMinutes: presignedMinutes,
		MaxUploadMB:                   maxUploadMB,
		AdminToken:                    getEnv("ADMIN_TOKEN", ""),
		LogToDB:                       getEnv("LOG_TO_DB", "true") != "false",
		LogRetentionDays:              logDays,
	}
	cfg.DatabaseURI = getEnv("DATABASE_URL", "")

	if err := cfg.validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// validate refuses to start production with a fallback secret or a bucket that
// will silently turn into in-memory storage.
func (c *Config) validate() error {
	if c.Env != "production" {
		return nil
	}
	if c.JWTSecret == "" || c.JWTSecret == defaultJWTSecret {
		return fmt.Errorf("production requires JWT_SECRET; refusing to run with the built-in default")
	}
	if c.R2AccessKeyID == "" || c.R2SecretAccessKey == "" || (c.R2Endpoint == "" && c.R2AccountID == "") {
		return fmt.Errorf("production requires R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY and R2_ENDPOINT or R2_ACCOUNT_ID")
	}
	return nil
}

// IsProduction reports whether the server runs with production safeguards.
func (c *Config) IsProduction() bool { return c.Env == "production" }

// MaxUploadBytes is the configured per-request upload cap in bytes.
func (c *Config) MaxUploadBytes() int64 {
	if c.MaxUploadMB <= 0 {
		return 0 // signal the handler to use its default
	}
	return int64(c.MaxUploadMB) << 20
}

func (c *Config) DatabaseURL() string {
	if c.DatabaseURI != "" {
		return c.DatabaseURI
	}
	return fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=%s",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName, c.DBSSLMode,
	)
}

func getEnv(key, defaultVal string) string {
	if val, ok := os.LookupEnv(key); ok && val != "" {
		return val
	}
	return defaultVal
}
