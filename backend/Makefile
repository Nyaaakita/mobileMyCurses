DB_URL ?= postgres://postgres:postgres@localhost:5432/lms?sslmode=disable

.PHONY: run
run:
	go run ./cmd/api

.PHONY: tidy
tidy:
	go mod tidy

.PHONY: migrate-up
migrate-up:
	goose -dir ./migrations postgres "$(DB_URL)" up

.PHONY: migrate-down
migrate-down:
	goose -dir ./migrations postgres "$(DB_URL)" down
