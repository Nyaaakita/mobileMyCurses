package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"

	"github.com/joho/godotenv"

	"lms/backend/internal/app"
	"lms/backend/internal/config"
)

func main() {
	// Dev convenience: load vars from backend/.env if present.
	_ = godotenv.Load()

	cfg := config.Load()

	application, err := app.New(cfg)
	if err != nil {
		log.Fatalf("init app: %v", err)
	}
	defer application.Close()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	log.Printf("api listening on %s", cfg.HTTPAddr)
	if err := application.Run(ctx); err != nil && err != http.ErrServerClosed {
		log.Fatalf("run api: %v", err)
	}
}
