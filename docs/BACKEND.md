# Backend — Go + Fiber v3 + GORM

Baca juga: `ARCHITECTURE.md` (aturan modul), `DATA_MODEL.md`, `SYNC_PROTOCOL.md`, `BUSINESS_RULES.md`, `API.md`.

## 1. Stack

| Kebutuhan | Library |
| --- | --- |
| Bahasa | Go 1.26, patch terbaru (`go 1.26` + `toolchain go1.26.<patch>` di `go.mod`) |
| Database | PostgreSQL 17 di Neon |
| HTTP | `github.com/gofiber/fiber/v3`, rilis stabil v3 terbaru (v2 sudah deprecated); handler `func(c fiber.Ctx) error` |
| ORM | `gorm.io/gorm` + `gorm.io/driver/postgres` (pgx) |
| Migration | `github.com/go-gormigrate/gormigrate/v2` |
| JSONB | `gorm.io/datatypes` |
| UUID v7 / v5 | `github.com/google/uuid` |
| Validasi | `github.com/go-playground/validator/v10` |
| JWT | `github.com/golang-jwt/jwt/v5` |
| JWKS (Apple/Google) | `github.com/MicahParks/keyfunc/v3` |
| Password | `golang.org/x/crypto/argon2` (argon2id) |
| Config | `github.com/caarlos0/env/v11` + `github.com/joho/godotenv` (lokal saja) |
| Email | `github.com/resend/resend-go/v2` |
| Log | `log/slog` (JSON) |
| Lint | `golangci-lint` |

Semua library memakai rilis stabil terbaru saat ditambahkan (bukan beta/rc), dikunci di `go.sum`. Library lain butuh persetujuan user.

## 2. Struktur folder

```
backend/
├── go.mod
├── go.sum
├── vercel.json
├── .env.example
├── .golangci.yml
├── Makefile
├── cmd/
│   ├── api/
│   │   └── main.go                     # entrypoint Vercel: load config → app.Build → Listen(PORT)
│   └── migrate/
│       └── main.go                     # go run ./cmd/migrate up|down|status (DATABASE_URL_DIRECT)
├── migrations/
│   └── migrations.go                   # SATU-SATUNYA file migration (gormigrate)
└── internal/
    ├── app/
    │   ├── app.go                      # composition root: buat semua modul & sambungkan
    │   ├── routes.go                   # /healthz, grup /v1, urutan middleware
    │   ├── onboarding.go               # implementasi identity.Onboarder (seed user baru)
    │   └── maintenance.go              # handler cron maintenance (memanggil Purger tiap modul)
    ├── platform/
    │   ├── config/
    │   │   ├── config.go               # Load(): config inti, divalidasi saat start
    │   │   ├── integrations.go         # struct Apple/Google/Email/RevenueCat + Validate() per integrasi
    │   │   └── migrate_config.go       # LoadMigrate(): hanya DATABASE_URL_DIRECT
    │   ├── database/
    │   │   ├── postgres.go             # Open(): GORM + pool settings, Ping, Close
    │   │   ├── gorm_logger.go          # logger GORM → slog (warn: query lambat > 300 ms; tanpa nilai parameter)
    │   │   ├── tx_manager.go           # WithTx(ctx, fn), DB(ctx) mengambil tx dari context
    │   │   ├── user_lock.go            # LockUser(ctx, tx, userID) → pg_advisory_xact_lock
    │   │   └── version.go              # NextSyncVersion(ctx, tx) → nextval
    │   ├── httpx/
    │   │   ├── app_error.go            # tipe AppError{Status, Code, Detail, Fields} + konstanta code
    │   │   ├── context.go              # kunci locals + accessor RequestID, UserID, SessionID, Client
    │   │   ├── problem.go              # serialisasi RFC 9457
    │   │   ├── error_handler.go        # fiber.Config.ErrorHandler
    │   │   ├── bind.go                 # BindAndValidate[T]
    │   │   └── response.go
    │   ├── middleware/
    │   │   ├── request_id.go
    │   │   ├── recover.go
    │   │   ├── access_log.go
    │   │   ├── client_info.go          # X-Device-ID, X-Platform, X-App-Version + cek versi minimum
    │   │   ├── semver.go               # pembanding versi semver (tanpa library)
    │   │   ├── auth.go                 # verifikasi JWT → userID di context
    │   │   ├── cron_auth.go            # Bearer CRON_SECRET
    │   │   └── webhook_auth.go         # Bearer REVENUECAT_WEBHOOK_SECRET
    │   ├── auth/
    │   │   ├── jwt.go                  # Issue/Verify access token
    │   │   ├── password.go             # argon2id Hash/Verify
    │   │   ├── refresh_token.go        # generate token acak + SHA-256
    │   │   ├── otp.go                  # kode 6 digit + HMAC
    │   │   └── oidc_verifier.go        # verifikasi ID token Apple & Google via JWKS
    │   ├── mailer/
    │   │   ├── mailer.go               # interface Mailer
    │   │   ├── resend_mailer.go
    │   │   └── log_mailer.go           # dipakai lokal: kode ditulis ke log
    │   ├── civil/
    │   │   └── date.go                 # tipe Date (YYYY-MM-DD): Scanner/Valuer/JSON
    │   ├── syncbase/
    │   │   ├── columns.go              # struct Columns (kolom wajib tabel [sync])
    │   │   ├── change.go               # Change, Result, PulledRow
    │   │   ├── handler.go              # interface Handler per entitas
    │   │   └── registry.go             # interface Registry (implementasi di modul sync)
    │   ├── clock/
    │   │   └── clock.go                # interface Clock (bisa di-mock)
    │   ├── idgen/
    │   │   └── idgen.go                # NewV7, V5 + konstanta namespace
    │   └── logger/
    │       └── logger.go
    ├── domainrules/                    # rumus murni BUSINESS_RULES.md, tanpa I/O
    │   ├── types.go                    # struct input nilai biasa (bukan entity GORM) yang dipakai bersama
    │   ├── rounding.go
    │   ├── period.go
    │   ├── balance.go
    │   ├── reconciliation.go
    │   ├── budget.go
    │   └── recurrence.go
    └── modules/
        ├── identity/
        │   ├── module.go
        │   ├── api.go                  # Onboarder, UserPurger, Users (API publik)
        │   └── internal/
        │       ├── model/              # user.go, auth_identity.go, refresh_token.go,
        │       │                       # verification_token.go, user_settings.go
        │       ├── repository/         # satu repository per model
        │       ├── service/            # auth_service.go, oauth_service.go, token_service.go,
        │       │                       # verification_service.go, account_service.go
        │       ├── handler/            # auth_handler.go, me_handler.go
        │       ├── dto/
        │       └── synchandler/        # user_settings_handler.go
        ├── category/
        │   ├── module.go
        │   ├── api.go                  # Categories: Get, SeedDefaults, CountCustom; ReferenceChecker (callback)
        │   └── internal/
        │       ├── model/category.go
        │       ├── repository/
        │       ├── service/            # category_service.go, default_categories.go
        │       └── synchandler/category_handler.go
        ├── wallet/
        │   ├── module.go
        │   ├── api.go                  # Accounts: Get, List, CreateCash, CountActive; Snapshots: Latest; ReferenceChecker (callback)
        │   └── internal/
        │       ├── model/              # account.go, balance_snapshot.go
        │       ├── repository/
        │       ├── service/
        │       └── synchandler/        # account_handler.go, balance_snapshot_handler.go
        ├── ledger/
        │   ├── module.go
        │   ├── api.go                  # Ledger: Aggregates, HasActiveReferences, PauseRules (HasActiveReferences = implementasi ReferenceChecker wallet & category)
        │   └── internal/
        │       ├── model/              # transaction.go, recurring_rule.go
        │       ├── repository/
        │       ├── service/            # transaction_service.go, recurring_service.go, aggregate_service.go
        │       ├── handler/            # cron_recurring_handler.go
        │       └── synchandler/        # transaction_handler.go, recurring_rule_handler.go
        ├── budget/
        │   ├── module.go
        │   ├── api.go                  # Goals: EffectiveFor(month), CreateDefault
        │   └── internal/
        │       ├── model/budget_goal.go
        │       ├── repository/
        │       ├── service/
        │       └── synchandler/budget_goal_handler.go
        ├── report/
        │   ├── module.go
        │   ├── api.go
        │   └── internal/
        │       ├── service/            # monthly_report_service.go, trend_service.go
        │       ├── handler/report_handler.go
        │       └── dto/
        ├── sync/
        │   ├── module.go
        │   ├── api.go                  # NewRegistry()
        │   └── internal/
        │       ├── model/idempotency_key.go
        │       ├── repository/
        │       ├── service/            # push_service.go, pull_service.go, registry.go
        │       ├── handler/sync_handler.go
        │       └── dto/
        └── billing/
            ├── module.go
            ├── api.go                  # Entitlements: IsPremium, Get
            └── internal/
                ├── model/              # subscription.go, entitlement.go, billing_event.go
                ├── repository/
                ├── service/            # webhook_service.go, entitlement_service.go, plan_limits.go
                ├── client/revenuecat_client.go
                └── handler/            # webhook_handler.go, entitlement_handler.go
```

## 3. Pola modul

### 3.1 `module.go`

```go
package ledger

type Deps struct {
    DB       *database.TxManager
    Clock    clock.Clock
    Wallet   wallet.Accounts      // API publik modul lain
    Category category.Categories
    Billing  billing.Entitlements
}

type Module struct {
    api     Ledger
    handler *handler.CronRecurringHandler
    syncs   []syncbase.Handler
}

func New(d Deps) *Module { /* rangkai repository → service → handler */ }

func (m *Module) API() Ledger                                  { return m.api }
func (m *Module) RegisterRoutes(internal fiber.Router)         { /* GET /cron/recurring */ }
func (m *Module) RegisterSyncHandlers(r syncbase.Registry)     { for _, h := range m.syncs { r.Register(h) } }
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error { /* hapus data user */ }
```

### 3.2 `api.go`

Berisi interface dan DTO publik saja. Tidak boleh mengekspos model GORM.

```go
package ledger

type Ledger interface {
    Aggregates(ctx context.Context, userID uuid.UUID, q AggregateQuery) (AggregateResult, error)
    HasActiveReferences(ctx context.Context, userID uuid.UUID, ref Reference) (bool, error)
    PauseRules(ctx context.Context, userID uuid.UUID) error
}
```

### 3.3 Layer

| Layer | Tanggung jawab | Tidak boleh |
| --- | --- | --- |
| handler | Bind + validasi DTO, ambil `userID` dari context, panggil service, bentuk respons | Logika bisnis, akses GORM |
| service | Aturan bisnis, transaksi (`TxManager.WithTx`), memanggil API modul lain | Tahu tentang Fiber |
| repository | Query GORM, selalu filter `user_id` | Aturan bisnis |
| model | Struct GORM, satu per file | Method yang mengakses database |
| synchandler | Implementasi `syncbase.Handler` untuk satu entitas, memakai service yang sama dengan endpoint | Validasi sendiri yang berbeda dari service |

### 3.4 Sync handler

```go
package syncbase

type Handler interface {
    Entity() string
    // LoadForWrite mengambil baris berdasarkan id tanpa filter user (untuk cek kepemilikan dan LWW).
    LoadForWrite(ctx context.Context, id uuid.UUID) (*Existing, error)
    Upsert(ctx context.Context, userID uuid.UUID, c Change) error   // validasi + tulis seluruh baris
    Delete(ctx context.Context, userID uuid.UUID, c Change) error   // tombstone
    PullSince(ctx context.Context, userID uuid.UUID, since int64, limit int) ([]PulledRow, error)
}

type Existing struct {
    UserID    uuid.UUID
    UpdatedAt time.Time
}
```

`server_version` dan `server_updated_at` diisi oleh helper bersama di `syncbase` (memanggil `database.NextSyncVersion`), bukan oleh masing-masing handler.

## 4. Platform

### 4.1 Config (env)

Config dibagi dua kelompok:

- **Inti**: divalidasi oleh `config.Load()` saat start; variabel wajib kosong → server gagal start dengan pesan jelas.
- **Integrasi** (Resend, Apple, Google, RevenueCat): dibaca oleh `config.Load()` ke struct per integrasi tetapi **tidak** divalidasi saat start. Validasi wajib-isi dipanggil saat modul yang memakainya dihubungkan di composition root (Fase 1 untuk Resend/Apple/Google, Fase 3 untuk RevenueCat). Dengan begitu deploy Fase 0 tidak gagal karena rahasia yang belum ada.
- `cmd/migrate` memakai `config.LoadMigrate()` yang hanya membutuhkan `DATABASE_URL_DIRECT`.

**Variabel inti**

| Variabel | Wajib | Contoh / keterangan |
| --- | --- | --- |
| `APP_ENV` | ya | `local`, `preview`, `production` |
| `PORT` | tidak | default `8080` (Vercel mengisinya saat deploy) |
| `DATABASE_URL` | ya | Neon **pooled**, tambahkan `?sslmode=require&connect_timeout=10` |
| `DATABASE_URL_DIRECT` | migrate saja | Neon **direct** |
| `JWT_SECRET` | ya | ≥ 32 byte acak |
| `JWT_ISSUER` | ya | `moneytracker-api` |
| `ACCESS_TOKEN_TTL` | tidak | default `15m` |
| `REFRESH_TOKEN_TTL` | tidak | default `1440h` (60 hari) |
| `OTP_SECRET` | ya | ≥ 32 byte acak |
| `CRON_SECRET` | ya | ≥ 16 karakter acak, sama dengan env Vercel |
| `MIN_APP_VERSION_ANDROID` | tidak | default `0.0.0` |
| `MIN_APP_VERSION_IOS` | tidak | default `0.0.0` |
| `LOG_LEVEL` | tidak | default `info` |

**Variabel integrasi** (divalidasi saat modul terkait dihubungkan)

| Variabel | Wajib saat modul aktif | Contoh / keterangan |
| --- | --- | --- |
| `APPLE_BUNDLE_ID` | identity OAuth (Fase 1) | `aud` token Apple |
| `GOOGLE_CLIENT_IDS` | identity OAuth (Fase 1) | Daftar dipisah koma (web client ID untuk Android Credential Manager + iOS client ID) |
| `RESEND_API_KEY` | identity, production (Fase 1) | Kosong di lokal → `log_mailer` |
| `EMAIL_FROM` | identity (Fase 1) | `Money Tracker <no-reply@domain>` |
| `REVENUECAT_WEBHOOK_SECRET` | billing (Fase 3) | Nilai header Authorization webhook |
| `REVENUECAT_SECRET_API_KEY` | billing (Fase 3) | Untuk mengambil status subscriber terbaru |

**Migrate**: `DATABASE_URL_DIRECT` (wajib untuk `cmd/migrate`, tidak dibaca oleh API).

### 4.2 Database

- `postgres.New(postgres.Config{DSN: cfg.DatabaseURL, PreferSimpleProtocol: true})` agar aman di PgBouncer mode transaction.
- Pool kecil karena serverless: `MaxOpenConns 5`, `MaxIdleConns 2`, `ConnMaxIdleTime 30s`, `ConnMaxLifetime 5m`.
- GORM: `PrepareStmt: false`, `SkipDefaultTransaction: true`, logger GORM diarahkan ke slog (level warn, slow query > 300 ms).
- `TxManager.WithTx(ctx, fn)` menyimpan `*gorm.DB` transaksi di context; `TxManager.DB(ctx)` mengembalikan tx bila ada, selain itu koneksi biasa. Semua repository wajib memakai `DB(ctx)`.

### 4.3 Pengecualian raw SQL

Raw SQL **hanya** diizinkan di tempat berikut, masing-masing dibungkus satu fungsi:

| Lokasi | SQL | Alasan |
| --- | --- | --- |
| `migrations/migrations.go` | `CREATE SEQUENCE sync_version_seq` / `DROP SEQUENCE` | GORM Migrator tidak punya API sequence |
| `platform/database/version.go` | `SELECT nextval('sync_version_seq')` | Ambil versi sync |
| `platform/database/user_lock.go` | `SELECT pg_advisory_xact_lock(hashtextextended(?, 0))` | Advisory lock per user (`SYNC_PROTOCOL.md` §10) |
| Repository agregat | Ekspresi di `Select(...)` seperti `COALESCE(SUM(amount), 0)` | Agregat lewat query builder GORM, bukan `db.Raw` |

Di luar itu, gunakan query builder GORM. `db.Raw` / `db.Exec` dengan string SQL lain dilarang tanpa persetujuan.

### 4.4 HTTP

- Fiber config: `BodyLimit 1 MB`, `ReadTimeout 10s`, `WriteTimeout 15s`, `ErrorHandler = httpx.ErrorHandler`.
- Urutan middleware global: `request_id` → `recover` → `access_log`.
- Grup route:

| Grup | Middleware tambahan |
| --- | --- |
| `/v1/auth/*` (publik) | `client_info` |
| `/v1/*` lainnya untuk app | `client_info` → `auth` |
| `/v1/internal/cron/*` | `cron_auth` (tanpa `client_info`) |
| `/v1/billing/webhooks/revenuecat` | `webhook_auth` (tanpa `client_info`) |
| `/healthz` | – (cek database dengan timeout maksimal 2 detik; respons `200 {"status":"ok"}` atau `503 {"status":"unavailable"}` tanpa detail error, detail hanya di log) |
- Semua error dikembalikan sebagai `*httpx.AppError`; error lain dipetakan ke `500 internal` dan dilog dengan `request_id`.
- Handler mengambil `context.Context` dari request Fiber dan meneruskannya ke service.

## 5. Migration

- Satu file: `backend/migrations/migrations.go`, berisi `func All() []*gormigrate.Migration`.
- Migration pertama: ID `202611020001_init`, membuat semua tabel di `DATA_MODEL.md`, index, dan sequence.
- Migration berikutnya ditambahkan sebagai elemen baru di slice yang sama, ID berformat `YYYYMMDDNNNN_deskripsi`. Migration yang sudah dijalankan **tidak boleh diubah**.
- Setiap migration memakai **struct snapshot** yang dideklarasikan di dalam fungsi `Migrate`-nya sendiri (bukan model dari `internal/modules`). Ini satu-satunya pengecualian aturan "satu model per file", supaya migration lama tidak ikut berubah saat model aplikasi berubah.
- Gunakan `tx.Migrator().CreateTable(&snapshot{})`, `CreateIndex`, dan tag GORM (`type:`, `not null`, `default:`, `index:`, `uniqueIndex:`).
- **Foreign key hanya yang disebut eksplisit di `DATA_MODEL.md`**: `auth_identities.user_id`, `refresh_tokens.user_id`, `verification_tokens.user_id` → `users.id` (`ON DELETE CASCADE`), `balance_snapshots.account_id` → `accounts.id`, dan `entitlements.subscription_id` → `subscriptions.id`. Tabel lain tidak diberi FK; kepemilikan data (`user_id`) dan referensi lintas tabel divalidasi di service/handler. Semua index di `DATA_MODEL.md` (termasuk `(user_id, server_version)` di tabel [sync] dan index kolom relasi) tetap dibuat.
- Setiap migration wajib punya `Rollback`.
- `cmd/migrate` menerima `up`, `down` (rollback satu langkah), dan `status`, memakai `DATABASE_URL_DIRECT`.

```go
// pola satu migration
{
    ID: "202611020001_init",
    Migrate: func(tx *gorm.DB) error {
        type account struct {
            ID             uuid.UUID `gorm:"type:uuid;primaryKey"`
            UserID         uuid.UUID `gorm:"type:uuid;not null;index:idx_accounts_user_version,priority:1"`
            Name           string    `gorm:"type:varchar(50);not null"`
            // … kolom lain sesuai DATA_MODEL.md
            ServerVersion  int64     `gorm:"not null;index:idx_accounts_user_version,priority:2"`
        }
        return tx.Migrator().CreateTable(&account{} /*, … */)
    },
    Rollback: func(tx *gorm.DB) error { return tx.Migrator().DropTable("accounts" /*, … */) },
}
```

## 6. Detail per modul

### 6.1 identity

- **Register**: validasi → cek email (lowercase) → hash argon2id (`m=19456 KiB, t=2, p=1`) → dalam satu tx dengan `LockUser`: buat user + panggil `Onboarder.Onboard(ctx, userID, timezone)` → buat sesi → kirim kode verifikasi (setelah commit).
- **Onboarder** diimplementasikan di `internal/app/onboarding.go`, memanggil `category.SeedDefaults`, `wallet.CreateCash`, `budget.CreateDefault`, dan membuat `user_settings`. Identity tidak meng-import modul lain.
- **Login**: user `locked_until` > now → `423`. Password salah → `failed_login_count++`, mencapai 10 → lock 15 menit. Sukses → reset counter.
- **Access token** claims: `sub` (user ID), `sid` (`family_id`), `iss`, `aud = moneytracker-app`, `iat`, `exp`.
- **Refresh rotation**: cari token by hash. Tidak ada / kedaluwarsa / dicabut → `refresh_invalid`. Sudah `rotated_at` → **reuse terdeteksi**: cabut semua token di family → `refresh_reused`. Sukses → tandai `rotated_at`, buat token baru di family yang sama.
- **OAuth**: verifikasi ID token via JWKS (Apple: `https://appleid.apple.com/auth/keys`, `iss = https://appleid.apple.com`, `aud = APPLE_BUNDLE_ID`; Google: `https://www.googleapis.com/oauth2/v3/certs`, `iss ∈ {accounts.google.com, https://accounts.google.com}`, `aud ∈ GOOGLE_CLIENT_IDS`). Cari `auth_identities (provider, sub)`:
    1. Ada → login.
    2. Tidak ada, email dari provider terverifikasi dan sama dengan user yang email-nya sudah terverifikasi → tautkan identity ke user itu.
    3. Tidak ada, email sama dengan user yang belum terverifikasi → `409 email_taken` (minta login dengan password dulu).
    4. Selain itu → buat user baru (`email_verified_at` = now bila provider menyatakan terverifikasi) + onboarding.
- **Hapus akun**: `status = pending_deletion`, cabut semua token. Cron maintenance menghapus permanen setelah 30 hari lewat `PurgeUser` setiap modul.

### 6.2 category, wallet, budget

- Validasi sesuai `BUSINESS_RULES.md` §6 dan batas paket §7 (memanggil `billing.Entitlements.IsPremium`).
- wallet dan category masing-masing mendefinisikan `ReferenceChecker` (`HasActiveReferences(ctx, userID, id) (bool, error)`) di `api.go` dan menerimanya lewat `Deps`. Dipakai untuk menolak penghapusan akun/kategori yang masih dirujuk transaksi aktif. Implementasinya `ledger.HasActiveReferences`, disambungkan di `internal/app/app.go` (ledger bergantung ke wallet dan category, jadi tidak boleh sebaliknya).
- `category.SeedDefaults`: daftar dari `BUSINESS_RULES.md` §2.1, ID UUIDv7 baru.
- `wallet.CreateCash`: akun Cash + snapshot saldo awal.
- `budget.CreateDefault`: ID deterministik sesuai `SYNC_PROTOCOL.md` §3.

### 6.3 ledger

- Validasi transaksi memakai `wallet.Accounts` dan `category.Categories` untuk kepemilikan referensi. Referensi belum ada → error `reference_missing`.
- Recurring hanya bisa dibuat/diaktifkan bila premium.
- `Aggregates` menyediakan jumlah per tipe, per alokasi, per kategori, dan arus per akun untuk rentang tanggal (dipakai report).
- Cron recurring: iterasi user yang punya rule aktif dan premium, per user dalam tx terpisah dengan `LockUser`, memakai `domainrules.Recurrence`.

### 6.4 report

- Mengambil data dari `ledger.Aggregates`, `wallet` (akun + snapshot terbaru), `budget.EffectiveFor`, lalu menghitung dengan `domainrules`.
- Batas riwayat dan fitur premium ditegakkan di sini (`history_limit`, `premium_required`).

### 6.5 sync

- Mengimplementasikan registry, push, dan pull sesuai `SYNC_PROTOCOL.md` §8–§10.
- Push: satu tx, `LockUser`, savepoint per entri, simpan respons ke `sync_idempotency_keys`.
- Pull: panggil `PullSince(since, limit+1)` di setiap handler, gabungkan, urutkan, potong ke `limit`, hitung `has_more`.
- `meta.entitlement` diambil dari `billing.Entitlements.Get`.

### 6.6 billing

- App memanggil `Purchases.logIn(<user_id>)` sehingga `app_user_id` RevenueCat = user ID server.
- Webhook: verifikasi header → simpan `billing_events` (insert dengan PK event ID; duplikat → balas 200 tanpa proses) → ambil status subscriber terbaru dari RevenueCat REST API memakai `REVENUECAT_SECRET_API_KEY` (webhook bisa datang tidak berurutan) → perbarui `subscriptions` dan `entitlements`.
- Event dengan `app_user_id` anonim (`$RCAnonymousID:…`) disimpan, tidak diproses.
- Entitlement berubah dari aktif ke tidak aktif → panggil `PremiumEndedHandler` (interface di `billing/api.go`) dalam tx dengan `LockUser`. Composition root (`internal/app/app.go`) mengimplementasikannya dengan `ledger.PauseRules`, karena billing tidak boleh meng-import ledger.
- `plan_limits.go` berisi konstanta batas paket (`BUSINESS_RULES.md` §7).

## 7. Vercel

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "framework": "go",
  "regions": ["sin1"],
  "crons": [
    { "path": "/v1/internal/cron/recurring", "schedule": "0 18 * * *" },
    { "path": "/v1/internal/cron/maintenance", "schedule": "30 18 * * *" }
  ]
}
```

- Vercel Project → Root Directory `backend`. Entrypoint `cmd/api/main.go`, server listen di env `PORT`.
- Set semua env §4.1 di Vercel (Production dan Preview terpisah).
- Migration dijalankan manual sebelum deploy yang membutuhkan skema baru.

## 8. Testing

Tidak ada file test (lihat `CLAUDE.md`). Verifikasi otomatis cukup `go build ./...`, `go vet ./...`, dan `golangci-lint run`. Skenario `SYNC_PROTOCOL.md` §13 dan contoh `BUSINESS_RULES.md` §9.3 dipakai user untuk pengujian manual.

## 9. Konvensi kode

- `context.Context` selalu parameter pertama.
- Error dibungkus `fmt.Errorf("…: %w", err)`; error domain memakai sentinel/tipe di package service, lalu dipetakan ke `AppError` di handler.
- Tidak ada state global selain yang dibuat di composition root.
- Waktu selalu lewat `clock.Clock`, ID lewat `idgen`.
- Nama file `snake_case.go`, satu tipe utama per file.
