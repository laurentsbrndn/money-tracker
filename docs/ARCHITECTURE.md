# Arsitektur

## 1. Gambaran sistem

```
┌──────────────────────┐     ┌──────────────────────┐        ┌──────────────┐
│ Android (Flutter)    │     │ iOS (SwiftUI)        │        │ App Store /  │
│ Drift + outbox       │     │ GRDB + outbox        │        │ Play Store   │
│ RevenueCat SDK       │     │ RevenueCat SDK       │        └──────┬───────┘
└──────────┬───────────┘     └──────────┬───────────┘               │
           │  HTTPS /v1 (auth, sync, laporan, entitlement)           ▼
           ▼                            ▼                    ┌──────────────┐
┌──────────────────────────────────────────────────────────┐ │ RevenueCat   │
│ Vercel — satu binary Go (Fiber v3), region sin1          │◀┤ webhook      │
│                                                          │ └──────────────┘
│  modules: identity · category · wallet · ledger · budget │ ┌──────────────┐
│           report · sync · billing                        │◀┤ Vercel Cron  │
│  platform: config · database · httpx · middleware · auth │ │ (GET harian) │
└──────────────────────────┬───────────────────────────────┘ └──────────────┘
                           │ GORM (pgx), pooled connection
                           ▼
                ┌────────────────────────┐
                │ Neon PostgreSQL 17     │
                │ region ap-southeast-1  │
                └────────────────────────┘
```

- Kedua app **offline-first**: UI membaca/menulis database lokal, lalu sinkron ke server. Detail di `SYNC_PROTOCOL.md`.
- Backend adalah **satu deployable** (modular monolith). Modul dipisah secara logis dan dijaga oleh aturan import Go.
- Server adalah sumber kebenaran bersama (multi-device + backup) dan sumber kebenaran status premium.

## 2. Keputusan utama

| # | Keputusan | Alasan |
| --- | --- | --- |
| D1 | Modular monolith, bukan microservices | Satu developer, satu deploy, tetap bisa dipecah nanti lewat interface modul |
| D2 | Offline-first dengan outbox + push/pull cursor | App keuangan harus bisa mencatat tanpa sinyal |
| D3 | Last-write-wins per baris (`updated_at` client) | App pribadi, konflik antar device jarang; sederhana dan dapat diprediksi |
| D4 | Uang `BIGINT` rupiah | Menghindari error pembulatan float |
| D5 | Satu tabel `transactions` untuk 4 tipe | Query ringkasan dan sync lebih sederhana |
| D6 | Savings = transfer ke akun `savings` + expense beralokasi savings | Menabung tidak mengurangi total uang, jadi rekonsiliasi tetap akurat |
| D7 | Expected balance dihitung, tidak disimpan | Selalu konsisten setelah edit transaksi lama |
| D8 | Kategori default disalin per user | Query sederhana (`WHERE user_id`), user bebas mengubah |
| D9 | Subscription lewat RevenueCat, entitlement disimpan di server | Satu jalur untuk App Store dan Play Store, server menegakkan batas |
| D10 | Contract-first OpenAPI + contoh perhitungan bersama | Dua client native tidak boleh beda tafsir API maupun rumus |
| D11 | CRUD entitas lewat sync, bukan REST per entitas | Satu jalur tulis untuk offline-first; REST per entitas bisa ditambah nanti untuk web |

## 3. Aturan modular monolith (backend)

### 3.1 Struktur modul

Setiap modul berada di `backend/internal/modules/<nama>/`:

```
<nama>/
├── module.go        # constructor + RegisterRoutes + RegisterSyncHandlers
├── api.go           # interface publik + DTO publik untuk modul lain
└── internal/        # TIDAK bisa di-import modul lain (dipaksa compiler Go)
    ├── model/       # entity GORM, satu file per model
    ├── repository/
    ├── service/
    ├── handler/     # handler Fiber
    └── dto/         # request/response HTTP
```

### 3.2 Aturan

1. Modul lain hanya boleh meng-import `modules/<nama>` (yaitu `api.go`), tidak pernah `modules/<nama>/internal/...`.
2. Setiap tabel dimiliki **tepat satu modul**. Hanya modul pemilik yang boleh menulis dan membaca tabel itu lewat GORM. Modul lain meminta data lewat interface publik.
3. Tidak ada dependency melingkar. Graf dependency yang diizinkan:

```
platform  ◀── semua modul

billing   (tidak bergantung ke modul lain; PremiumEndedHandler diinjeksi composition root)
identity  (tidak bergantung ke modul lain; Onboarder & UserPurger diinjeksi composition root)
category  ──▶ billing                 (ReferenceChecker diinjeksi composition root; implementasi: ledger)
wallet    ──▶ billing                 (ReferenceChecker diinjeksi composition root; implementasi: ledger)
ledger    ──▶ wallet, category, billing
budget    (tidak bergantung ke modul lain)
report    ──▶ ledger, wallet, budget, billing
sync      ──▶ billing (meta.entitlement); entitas lain lewat SyncHandler yang didaftarkan modul
```

Bila modul A perlu memicu sesuatu di modul B tetapi B sudah bergantung ke A (contoh: billing harus mem-pause recurring di ledger, padahal ledger bergantung ke billing), A mendefinisikan interface callback di `api.go`-nya dan composition root menyambungkannya ke B. Tidak boleh ada import melingkar.

Callback yang ada saat ini:

| Callback (didefinisikan di) | Method | Diimplementasikan oleh | Tujuan |
| --- | --- | --- | --- |
| `billing.PremiumEndedHandler` | `OnPremiumEnded(ctx, userID)` | ledger (`PauseRules`) | Pause recurring saat premium berakhir |
| `identity.Onboarder` | `Onboard(ctx, userID, timezone)` | `internal/app/onboarding.go` | Seed user baru |
| `identity.UserPurger` | `PurgeUser(ctx, userID)` | tiap modul | Hapus data user |
| `wallet.ReferenceChecker` | `HasActiveReferences(ctx, userID, id)` | ledger | Akun tidak boleh dihapus bila masih dirujuk transaksi aktif |
| `category.ReferenceChecker` | `HasActiveReferences(ctx, userID, id)` | ledger | Kategori tidak boleh dihapus bila masih dirujuk transaksi aktif |

wallet dan category tidak boleh meng-import ledger (ledger sudah bergantung ke keduanya). Karena itu masing-masing mendefinisikan interface `ReferenceChecker` kecil di `api.go`, ledger mengimplementasikannya, dan composition root menyambungkannya.

4. Transaksi database lintas modul memakai `platform/database.TxManager`: transaksi disimpan di `context.Context`, dan setiap repository mengambil `*gorm.DB` dari context bila ada.
5. Komunikasi antar modul **sinkron lewat interface**, bukan event bus. Kalau suatu saat modul perlu dipisah jadi service, implementasi interface diganti menjadi HTTP client.
6. Composition root ada di `backend/internal/app/`: di sinilah semua modul dibuat dan disambungkan.

### 3.3 Kepemilikan tabel

| Modul | Tabel |
| --- | --- |
| identity | `users`, `auth_identities`, `refresh_tokens`, `verification_tokens`, `user_settings` |
| category | `categories` |
| wallet | `accounts`, `balance_snapshots` |
| ledger | `transactions`, `recurring_rules` |
| budget | `budget_goals` |
| report | – (komposisi data dari ledger, wallet, budget) |
| sync | `sync_idempotency_keys`, sequence `sync_version_seq` |
| billing | `subscriptions`, `entitlements`, `billing_events` |

## 4. Arsitektur client

Kedua app memakai pola yang sama walau bahasanya berbeda:

```
UI (Screen/View)
   │  observe state
   ▼
Controller / ViewModel  ── memanggil ──▶  Repository (fitur)
                                             │ baca/tulis
                                             ▼
                                   Database lokal (sumber data UI)
                                             │ outbox
                                             ▼
                                   SyncEngine ──▶ API client (hasil generate OpenAPI)
```

- UI **tidak pernah** memanggil API langsung untuk data domain. Semua lewat database lokal.
- Pengecualian yang memang butuh online: login/register, reset password, hapus akun, refresh entitlement, laporan yang diminta dari server (opsional).
- `DomainRules` (rumus saldo, budget, periode) adalah kode murni tanpa I/O; hasilnya harus sama dengan contoh di `BUSINESS_RULES.md` §9.3.

## 5. Keamanan

- Password di-hash dengan **argon2id**.
- Access token JWT (HS256) berumur 15 menit. Refresh token opaque 32 byte acak, disimpan sebagai hash SHA-256, dirotasi setiap dipakai, dengan deteksi reuse per `family_id`.
- Login Apple/Google: verifikasi ID token di server (signature JWKS, `iss`, `aud`, `exp`).
- Semua query data domain wajib difilter `user_id` dari token. `user_id` dari body request selalu diabaikan.
- Webhook RevenueCat diverifikasi lewat header Authorization rahasia. Endpoint cron diverifikasi lewat `Authorization: Bearer <CRON_SECRET>`.
- Client: token di Keychain (iOS) / Android Keystore via `flutter_secure_storage`. Database lokal Android dienkripsi SQLite3MultipleCiphers; iOS memakai Data Protection (`completeUntilFirstUserAuthentication`).
- Rate limiting: aktifkan Vercel Firewall rate limit untuk `/v1/auth/*`. Selain itu ada penghitung gagal login di database (lockout 15 menit setelah 10 kali gagal).

## 6. Deployment & environment

| Item | Nilai |
| --- | --- |
| Vercel project | Root Directory = `backend`, framework preset `go`, entrypoint `cmd/api/main.go`, server listen di env `PORT` |
| Region | Vercel function `sin1`, Neon `aws-ap-southeast-1` |
| Versi PostgreSQL | 17 (dipilih saat membuat project Neon) |
| Database URL app | Neon **pooled** (`-pooler` di hostname) |
| Database URL migration | Neon **direct** |
| Branch Neon | `main` (production), `dev` (development & preview) |
| Cron | `vercel.json` → GET ke `/v1/internal/cron/*`, jadwal dalam UTC, hanya jalan di production |
| Migration | Dijalankan manual `go run ./cmd/migrate up` dengan `DATABASE_URL_DIRECT`, sebelum deploy yang butuh skema baru |

Environment: `local` (Neon branch `dev`), `preview` (Neon branch `dev`), `production` (Neon branch `main`).

## 7. Observability

- Log terstruktur JSON (`log/slog`) ke stdout, terbaca di Vercel Logs. Setiap request punya `request_id` (header `X-Request-ID`).
- Jangan log token, password, atau body transaksi lengkap. Nominal boleh dilog di level debug saja.
- `GET /healthz` mengecek koneksi database.
- Client: crash reporting (Firebase Crashlytics di Android, bawaan Xcode Organizer di iOS) ditambahkan di Fase 4, bukan MVP.
