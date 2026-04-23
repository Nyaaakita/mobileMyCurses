# Educational LMS (Flutter + Go)

Monorepo with:

- `backend/` - Go API (chi + pgx + JWT), PostgreSQL, goose migrations.
- `mobile/` - Flutter mobile app with student/admin role flows and cache-first repository.

## Quick start

1. Поднять PostgreSQL, например: `docker compose up -d` в корне репозитория.
2. В `backend/`:
   - `go mod tidy`
   - `make run` — при старте API автоматически применяются goose-миграции (SQL зашиты в бинарник).
   - Опционально: CLI `goose` и цели `make migrate-up` / `make migrate-down` — для ручного отката или без запуска API.
3. In `mobile/`:
   - `flutter pub get`
   - `flutter run`

## Runbook (local)

### Backend

1. Создайте env:
   - Windows PowerShell: `Copy-Item .env.example .env`
2. Запустите API:
   - `go run ./cmd/api`
3. Проверка:
   - `curl http://127.0.0.1:8080/healthz`

Важно:
- По умолчанию API слушает `:8080`.
- Для прод-режима задайте безопасный `JWT_SECRET`.

### Mobile (Android / iOS)

- **Android-эмулятор:** по умолчанию `http://10.0.2.2:8080`.
- **iOS Simulator (macOS):** по умолчанию `http://127.0.0.1:8080` (API на той же машине).
- **Физическое устройство (Android или iPhone):** IP компьютера в Wi-Fi:
  - `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080`

Сборка под iOS выполняется на **macOS** с установленным Xcode: в каталоге `mobile/` — `cd ios && pod install` (при первом запуске или после смены плагинов), затем `flutter run` или открыть `ios/Runner.xcworkspace` в Xcode.

### Demo account

- email: `admin@example.com`
- password: `password123`

## Troubleshooting

- **`No supported devices connected`**
  - Android: в `mobile/` должна быть папка `android/`. При необходимости: `flutter create . --platforms=android`.
  - iOS: в `mobile/` должна быть папка `ios/`, устройство или Simulator, сборка с Mac + Xcode.

- **Приложение не логинится на физическом телефоне**
  - Проверьте `API_BASE_URL` (IP ПК, а не `10.0.2.2`).
  - Проверьте доступность `http://<PC_IP>:8080/healthz` с телефона.
  - Проверьте Windows Firewall (порт 8080).

- **`flutter pub get` ругается на SDK**
  - Проверьте `flutter --version` и `flutter doctor`.
  - Для этого проекта минимальная версия Dart в `mobile/pubspec.yaml` — `>=3.3.0`.

## Basic checks before commit

- Backend:
  - `go test ./...`
  - `go build ./...`
- Mobile:
  - `flutter analyze`
  - `flutter test`
