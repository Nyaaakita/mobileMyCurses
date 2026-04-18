package migrate

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"lms/backend/migrations"
)

// Up применяет все pending-миграции goose к базе, связанной с pool.
func Up(ctx context.Context, pool *pgxpool.Pool) error {
	db := stdlib.OpenDBFromPool(pool)
	defer db.Close()

	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("goose dialect: %w", err)
	}

	goose.SetBaseFS(migrations.FS)
	defer goose.SetBaseFS(nil)

	runCtx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()

	if err := goose.UpContext(runCtx, db, "."); err != nil {
		return fmt.Errorf("goose up: %w", err)
	}

	// Проверка, что соединение живо после миграций
	if err := db.PingContext(runCtx); err != nil {
		return fmt.Errorf("ping after migrate: %w", err)
	}

	return nil
}
