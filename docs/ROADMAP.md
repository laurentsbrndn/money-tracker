# Roadmap

Kerjakan berurutan: fase demi fase, dan di dalam fase: **Kontrak → Backend → Flutter → iOS**. Centang item saat selesai. Item bertanda (manual) dikerjakan manual oleh user.

## Langkah manual user (sebelum / selama fase terkait)

- [ ] (manual) Neon: buat project PostgreSQL 17 (region Singapore), branch `main` dan `dev`, simpan URL pooled dan direct. *(Fase 0)*
- [ ] (manual) Vercel: buat project dari repo, Root Directory `backend`, isi env sesuai `BACKEND.md` §4.1, aktifkan Firewall rate limit untuk `/v1/auth/*`. *(Fase 0)*
- [ ] (manual) Google Cloud: OAuth client ID tipe Web (untuk `serverClientId` Android), Android (package name + SHA-1), dan iOS. *(Fase 1)*
- [ ] (manual) Apple Developer: App ID + capability Sign in with Apple dan In-App Purchase. *(Fase 1)*
- [ ] (manual) Resend: verifikasi domain pengirim. *(Fase 1)*
- [ ] (manual) App Store Connect & Play Console: produk langganan `premium_monthly` dan `premium_yearly` dengan trial 7 hari. *(Fase 3)*
- [ ] (manual) RevenueCat: project, entitlement `premium`, offering default, webhook ke `/v1/billing/webhooks/revenuecat` dengan header Authorization rahasia. *(Fase 3)*

## Fase 0 — Fondasi

### Kontrak
- [x] `contracts/openapi.yaml` (OpenAPI 3.1) mencakup semua endpoint dan skema di `API.md` dan `SYNC_PROTOCOL.md`, termasuk problem+json
- [x] `contracts/fixtures/business_rules/01_monthly_basic.json` dari `BUSINESS_RULES.md` §9.3 (sudah disediakan, angka sudah diverifikasi)

### Backend
- [x] `go.mod`, struktur folder `BACKEND.md` §2, `Makefile`, `.golangci.yml`, `.env.example`, `vercel.json`
- [x] `platform/`: config, logger, database (Open, TxManager, LockUser, NextSyncVersion), httpx, middleware global, clock, idgen, civil, syncbase
- [x] `migrations/migrations.go` dengan `202611020001_init` (semua tabel `DATA_MODEL.md`) + `cmd/migrate`
- [x] `domainrules/` sesuai `BUSINESS_RULES.md`
- [x] `cmd/api` + `GET /healthz`
- [ ] (manual) Jalankan migration ke Neon `dev`, deploy pertama ke Vercel, cek `/healthz`

### Flutter
- [x] `flutter create` (platform Android saja, `minSdk 29`), `pubspec.yaml`, lint, l10n, struktur folder `FRONTEND_FLUTTER.md` §2
- [x] `app_config`, theme, router dengan 5 tab placeholder
- [x] Drift terenkripsi + semua tabel + DAO dasar
- [x] Client hasil `swagger_parser` + Dio + interceptor client info & problem
- [x] `domain_rules/` sesuai `BUSINESS_RULES.md`

### iOS
- [x] `project.yml` (deployment target iOS 18.0, tanpa target test), xcconfig, struktur folder `FRONTEND_IOS.md` §2, SPM packages
- [x] `AppContainer`, `RootView`, `MainTabView` dengan 5 tab placeholder
- [x] GRDB `AppDatabase` + `DatabaseMigrations` + semua record
- [x] Plugin OpenAPI generator + middleware client info
- [x] `DomainRules/` sesuai `BUSINESS_RULES.md`

## Fase 1 — Inti

### Backend
- [x] identity: register, login + lockout, OAuth Apple & Google, refresh rotation + reuse detection, logout, verifikasi email (kode), lupa/reset/ubah password, `GET/PATCH/DELETE /me`
- [x] Onboarding seed dalam satu transaksi (`DATA_MODEL.md` §9)
- [x] Sync handler: `user_settings`, `categories`, `accounts`, `balance_snapshots`, `transactions`, `budget_goals` dengan validasi `BUSINESS_RULES.md` §6
- [x] billing: `Entitlements` sementara (semua user free) + batas paket di §7
- [ ] (hardening) identity OAuth: verifikasi `nonce` (klaim `nonce` di ID token Apple/Google dibandingkan dengan field `nonce` request) setelah OAuth diuji dengan token asli; field sudah ada di kontrak
- [x] sync: push (idempotency, advisory lock, savepoint, LWW, clamp) dan pull (cursor, `has_more`, `meta`)
    - Catatan: terapkan aturan `null` pada `data` push (`SYNC_PROTOCOL.md` §8.1): key nullable yang tidak ada = `null`; field wajib non-null yang tidak ada → `rejected` `validation`.
- [ ] (manual) User menguji skenario S1–S7 dan S9–S11 (`SYNC_PROTOCOL.md` §13) serta kepemilikan data
- [ ] (manual) User menguji aturan `null` pada push: tanpa key nullable → tersimpan `null`; tanpa field wajib non-null → `rejected` `validation`

### Flutter
- [x] Session, token storage, auth interceptor (refresh single-flight)
- [x] Layar auth: login, daftar, Google, verifikasi email, lupa/reset password
- [x] Sync engine lengkap + scheduler + Workmanager + `SyncBadge`
    - Catatan: tipe field nullable hasil generator sudah berubah (UUID nullable → `String?`, timestamp nullable → `DateTime?`, enum alokasi inline). `EntityCodec` buatan sendiri untuk payload boleh dipakai tetapi tidak wajib.
    - Catatan: kolom penanda "sedang dikirim" di outbox diputuskan dan ditulis dulu di `SYNC_PROTOCOL.md` sebelum diimplementasi, di Flutter dan iOS. Skema v1 boleh diedit langsung (tanpa migration `onUpgrade`) karena app belum dirilis.
- [x] Onboarding, initial sync, setup wizard (Cash, akun, kategori)
- [x] Dashboard: ringkasan bulan + transaksi terbaru + pemilih bulan
- [x] Transaksi: daftar, filter, cari, form expense/income/transfer + biaya admin, edit, hapus + urungkan, duplikat
- [x] Akun: daftar, form, detail, arsip
- [x] Kategori: kelola
- [x] Pengaturan: profil, ubah password, sinkronisasi + "Perlu perhatian", keluar, hapus akun
- [x] Layar `upgrade_required`

### iOS
- [x] Semua item Flutter Fase 1 dengan padanan iOS
    - [x] Fondasi: skema lokal (`batch_id`, `sync_error`), Keychain, token, session, auth middleware (refresh single-flight)
    - [x] Sync engine lengkap + `SyncScheduler` + `BGAppRefreshTask` + `SyncBadge`
    - [x] Layar auth: login, daftar, Google, verifikasi email, lupa/reset password
    - [x] Onboarding, initial sync, setup wizard (Cash, akun, kategori)
    - [x] Akun: daftar, form, detail, arsip
    - [x] Kategori: kelola
    - [x] Transaksi: daftar, filter, cari, form expense/income/transfer + biaya admin, edit, hapus + urungkan, duplikat
    - [x] Dashboard: ringkasan bulan + transaksi terbaru + pemilih bulan
    - [x] Pengaturan: profil, ubah password, sinkronisasi + "Perlu perhatian", keluar, hapus akun
    - [x] Layar `upgrade_required`
    - Catatan sync engine: tipe field nullable hasil generator sudah berubah (UUID nullable → `String?`, timestamp nullable → `Date?`, enum alokasi inline). `EntityCodec` buatan sendiri untuk payload boleh dipakai tetapi tidak wajib.
- [x] Sign in with Apple

## Fase 2 — Uang aktual & budget

### Backend
- [x] Optimasi seed onboarding: versi sync diambil sekaligus (`NextSyncVersions`) dan insert massal per tabel, tetap satu transaksi (±46 query seed → 10)
- [x] report: `GET /v1/reports/monthly` (batas riwayat paket gratis)
- [x] Cron maintenance `GET /v1/internal/cron/maintenance` + `PurgeUser` di setiap modul

### Flutter
- [x] Cocokkan saldo (snapshot, selisih per akun, catat yang terlewat, adjustment)
- [x] Dashboard: kartu uang aktual, selisih, budget
- [x] Budget: atur goal (+ rencana income), halaman budget, rincian per kategori
- [x] Notifikasi lokal: harian, cocokkan saldo, peringatan budget, evaluasi bulan
- [x] Kunci app (PIN/biometrik), sembunyikan nominal, preferensi (timezone, tema)
- [x] `core/time/user_clock.dart` ("hari ini" di timezone user, port `Today` dari `domainrules/period.go`; pasang `timezone` dan `flutter_timezone`)

### iOS
- [x] Semua item Flutter Fase 2 dengan padanan iOS
    - [x] `UserClock` dengan timezone IANA pengguna (`TimeZone(identifier:)`), registrasi mengirim timezone perangkat
    - [x] Cocokkan saldo (snapshot, selisih per akun, catat yang terlewat, adjustment)
    - [x] Dashboard: kartu uang aktual, selisih, budget (`openingTotal` benar: seluruh transaksi diberikan ke `computeMonthlySummary`)
    - [x] Budget: atur goal (+ rencana income, 3 preset), halaman budget, rincian per kategori, kartu evaluasi; wizard 6 langkah
    - [x] Notifikasi lokal: harian, cocokkan saldo, peringatan budget (80% dan 100%), evaluasi bulan
    - [x] Kunci app (PIN/biometrik, overlay window), sembunyikan nominal, preferensi (timezone dengan pencarian, hari pertama minggu, tema)

## Fase 3 — Monetisasi

### Backend
- [x] billing: webhook RevenueCat (idempoten), ambil status subscriber, `subscriptions` + `entitlements`, `GET /v1/me/entitlements`, `meta.entitlement` di pull
- [x] Pause recurring saat premium berakhir
- [x] Sync handler `recurring_rules` (premium) + cron `GET /v1/internal/cron/recurring`
- [x] `GET /v1/reports/trend` (premium)
- [ ] (manual) User menguji skenario S8 dan S12

### Flutter
- [x] Catatan: perbaiki `openingTotal` pada `monthlySummary` dashboard Flutter sebelum laporan tren (hanya transaksi bulan terpilih yang diberikan ke `computeMonthlySummary`, sehingga `openingTotal` salah). iOS sudah benar sejak Fase 2
- [x] RevenueCat (`logIn`/`logOut`), paywall, layar langganan, pulihkan pembelian
- [x] Entitlement provider + toleransi offline 3 hari + UX batas paket (`plan_limit`)
- [x] Transaksi berulang: kelola aturan, generator lokal, konfirmasi pending
- [x] Laporan: per kategori, sumber income, tren, perbandingan, selisih tidak tercatat
- [x] Export CSV/PDF (`pdf` dan `share_plus` disetujui; CSV ditulis manual)

### iOS
- [ ] Semua item Flutter Fase 3 dengan padanan iOS

## Fase 4 — Pengembangan (belum dijadwalkan)

- [ ] Target tabungan
- [ ] Budget per kategori
- [ ] Shared budget (pasangan/keluarga)
- [ ] Versi web + endpoint REST per entitas
- [ ] Crash reporting
