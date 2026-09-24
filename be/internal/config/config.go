package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	Port                         string
	Env                          string
	DBHost                       string
	DBPort                       string
	DBUser                       string
	DBPassword                   string
	DBName                       string
	DBSSLMode                    string
	JWTSecret                    string
	JWTExpirationHours           int
	R2AccountID                  string
	R2AccessKeyID                string
	R2SecretAccessKey            string
	R2BucketName                 string
	R2Endpoint                   string
	PresignedURLExpirationMinutes int
}

func LoadConfig() (*Config, error) {
	// Load .env file if exists, ignore error if not found in production
	_ = godotenv.Load()

	jwtHours, _ := strconv.Atoi(getEnv("JWT_EXPIRATION_HOURS", "72"))
	presignedMinutes, _ := strconv.Atoi(getEnv("PRESIGNED_URL_EXPIRATION_MINUTES", "15"))

	cfg := &Config{
		Port:                         getEnv("PORT", "8080"),
		Env:                          getEnv("ENV", "development"),
		DBHost:                       getEnv("DB_HOST", "localhost"),
		DBPort:                       getEnv("DB_PORT", "5432"),
		DBUser:                       getEnv("DB_USER", "vaultly"),
		DBPassword:                   getEnv("DB_PASSWORD", "vaultly_secret"),
		DBName:                       getEnv("DB_NAME", "vaultly"),
		DBSSLMode:                    getEnv("DB_SSLMODE", "disable"),
		JWTSecret:                    getEnv("JWT_SECRET", "default_secret_key_change_me"),
		JWTExpirationHours:           jwtHours,
		R2AccountID:                  getEnv("R2_ACCOUNT_ID", ""),
		R2AccessKeyID:                getEnv("R2_ACCESS_KEY_ID", ""),
		R2SecretAccessKey:            getEnv("R2_SECRET_ACCESS_KEY", ""),
		R2BucketName:                 getEnv("R2_BUCKET_NAME", "vaultly-storage"),
		R2Endpoint:                   getEnv("R2_ENDPOINT", ""),
		PresignedURLExpirationMinutes: presignedMinutes,
	}

	return cfg, nil
}

func (c *Config) DatabaseURL() string {
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
