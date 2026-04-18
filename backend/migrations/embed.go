package migrations

import "embed"

// FS содержит SQL-файлы goose; используется при старте API.
//
//go:embed *.sql
var FS embed.FS
