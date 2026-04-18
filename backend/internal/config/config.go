package config

import (
	"os"
	"strconv"
)

type Config struct {
	HTTPAddr            string
	DatabaseURL         string
	JWTSecret           string
	JWTIssuer           string
	AccessTTLHours      int
	RefreshTTLHours     int
	AllowInsecureJWT    bool
	AuthRateLimitRPS    int
	AuthRateLimitBurst  int
}

func Load() Config {
	return Config{
		HTTPAddr:           getEnv("HTTP_ADDR", ":8080"),
		DatabaseURL:        getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/lms?sslmode=disable"),
		JWTSecret:          getEnv("JWT_SECRET", "dev-secret-change-me"),
		JWTIssuer:          getEnv("JWT_ISSUER", "lms-api"),
		AccessTTLHours:     getEnvInt("JWT_ACCESS_TTL_HOURS", 24),
		RefreshTTLHours:    getEnvInt("JWT_REFRESH_TTL_HOURS", 24*14),
		AllowInsecureJWT:   getEnvBool("ALLOW_INSECURE_JWT_SECRET", false),
		AuthRateLimitRPS:   getEnvInt("AUTH_RATE_LIMIT_RPS", 5),
		AuthRateLimitBurst: getEnvInt("AUTH_RATE_LIMIT_BURST", 10),
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return fallback
	}
	return v
}

func getEnvBool(key string, fallback bool) bool {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback
	}
	v, err := strconv.ParseBool(raw)
	if err != nil {
		return fallback
	}
	return v
}
