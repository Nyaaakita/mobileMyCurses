package app

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"lms/backend/internal/auth"
	"lms/backend/internal/config"
	"lms/backend/internal/db"
	"lms/backend/internal/httpx"
	"lms/backend/internal/migrate"
	"lms/backend/internal/store"
)

type App struct {
	server *http.Server
	store  *store.Store
}

func New(cfg config.Config) (*App, error) {
	if strings.TrimSpace(cfg.JWTSecret) == "" {
		return nil, fmt.Errorf("jwt secret is empty")
	}
	if !cfg.AllowInsecureJWT && cfg.JWTSecret == "dev-secret-change-me" {
		return nil, fmt.Errorf("refusing to start with insecure JWT_SECRET; set JWT_SECRET or ALLOW_INSECURE_JWT_SECRET=true")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	pool, err := db.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	migrateCtx, migrateCancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer migrateCancel()
	if err := migrate.Up(migrateCtx, pool); err != nil {
		pool.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}

	st := store.New(pool)
	router := httpx.NewRouter(httpx.Dependencies{
		Store: st,
		AccessTokenManager: auth.TokenManager{
			Secret: []byte(cfg.JWTSecret),
			Issuer: cfg.JWTIssuer,
			TTL:    time.Duration(cfg.AccessTTLHours) * time.Hour,
			TokenType: "access",
		},
		RefreshTokenManager: auth.TokenManager{
			Secret: []byte(cfg.JWTSecret),
			Issuer: cfg.JWTIssuer,
			TTL:    time.Duration(cfg.RefreshTTLHours) * time.Hour,
			TokenType: "refresh",
		},
		JWTSecret:          cfg.JWTSecret,
		AuthRateLimitRPS:   cfg.AuthRateLimitRPS,
		AuthRateLimitBurst: cfg.AuthRateLimitBurst,
	})

	return &App{
		server: &http.Server{
			Addr:              cfg.HTTPAddr,
			Handler:           router,
			ReadHeaderTimeout: 5 * time.Second,
			ReadTimeout:       15 * time.Second,
			WriteTimeout:      30 * time.Second,
			IdleTimeout:       60 * time.Second,
		},
		store: st,
	}, nil
}

func (a *App) Run(ctx context.Context) error {
	done := make(chan error, 1)
	go func() {
		done <- a.server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		return a.server.Shutdown(shutdownCtx)
	case err := <-done:
		return err
	}
}

func (a *App) Close() {
	a.store.Close()
}
