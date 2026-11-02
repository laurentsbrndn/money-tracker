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
- [ ] `project.yml` (deployment target iOS 18.0, tanpa target test), xcconfig, struktur folder `FRONTEND_IOS.md` §2, SPM packages
- [ ] `AppContainer`, `RootView`, `MainTabView` dengan 5 tab placeholder
- [ ] GRDB `AppDatabase` + `DatabaseMigrations` + semua record
- [ ] Plugin OpenAPI generator + middleware client info
- [ ] `DomainRules/` sesuai `BUSINESS_RULES.md`

## Fase 1 — Inti

### Backend
- [ ] identity: register, login + lockout, OAuth Apple & Google, refresh rotation + reuse detection, logout, verifikasi email (kode), lupa/reset/ubah password, `GET/PATCH/DELETE /me`
- [ ] Onboarding seed dalam satu transaksi (`DATA_MODEL.md` §9)
- [ ] Sync handler: `user_settings`, `categories`, `accounts`, `balance_snapshots`, `transactions`, `budget_goals` dengan validasi `BUSINESS_RULES.md` §6
- [ ] billing: `Entitlements` sementara (semua user free) + batas paket di §7
- [ ] sync: push (idempotency, advisory lock, savepoint, LWW, clamp) dan pull (cursor, `has_more`, `meta`)
- [ ] (manual) User menguji skenario S1–S7 dan S9–S11 (`SYNC_PROTOCOL.md` §13) serta kepemilikan data

### Flutter
- [ ] Session, token storage, auth interceptor (refresh single-flight)
- [ ] Layar auth: login, daftar, Google, verifikasi email, lupa/reset password
- [ ] Sync engine lengkap + scheduler + Workmanager + `SyncBadge`
    - Catatan: tambahkan penanda entri outbox "sedang dikirim" (SYNC_PROTOCOL §6.3.1) di skema Drift. Skema v1 boleh diedit langsung (tanpa migration `onUpgrade`) karena app belum dirilis.
- [ ] Onboarding, initial sync, setup wizard (Cash, akun, kategori)
- [ ] Dashboard: ringkasan bulan + transaksi terbaru + pemilih bulan
- [ ] Transaksi: daftar, filter, cari, form expense/income/transfer + biaya admin, edit, hapus + urungkan, duplikat
- [ ] Akun: daftar, form, detail, arsip
- [ ] Kategori: kelola
- [ ] Pengaturan: profil, ubah password, sinkronisasi + "Perlu perhatian", keluar, hapus akun
- [ ] Layar `upgrade_required`

### iOS
- [ ] Semua item Flutter Fase 1 dengan padanan iOS
- [ ] Sign in with Apple

## Fase 2 — Uang aktual & budget

### Backend
- [ ] report: `GET /v1/reports/monthly` (batas riwayat paket gratis)
- [ ] Cron maintenance `GET /v1/internal/cron/maintenance` + `PurgeUser` di setiap modul

### Flutter
- [ ] Cocokkan saldo (snapshot, selisih per akun, catat yang terlewat, adjustment)
- [ ] Dashboard: kartu uang aktual, selisih, budget
- [ ] Budget: atur goal (+ rencana income), halaman budget, rincian per kategori
- [ ] Notifikasi lokal: harian, cocokkan saldo, peringatan budget, evaluasi bulan
- [ ] Kunci app (PIN/biometrik), sembunyikan nominal, preferensi (timezone, tema)
- [ ] `core/time/user_clock.dart` ("hari ini" di timezone user, port `Today` dari `domainrules/period.go`; pasang `timezone` dan `flutter_timezone`)

### iOS
- [ ] Semua item Flutter Fase 2 dengan padanan iOS

## Fase 3 — Monetisasi

### Backend
- [ ] billing: webhook RevenueCat (idempoten), ambil status subscriber, `subscriptions` + `entitlements`, `GET /v1/me/entitlements`, `meta.entitlement` di pull
- [ ] Pause recurring saat premium berakhir
- [ ] Sync handler `recurring_rules` (premium) + cron `GET /v1/internal/cron/recurring`
- [ ] `GET /v1/reports/trend` (premium)
- [ ] (manual) User menguji skenario S8 dan S12

### Flutter
- [ ] RevenueCat (`logIn`/`logOut`), paywall, layar langganan, pulihkan pembelian
- [ ] Entitlement provider + toleransi offline 3 hari + UX batas paket (`plan_limit`)
- [ ] Transaksi berulang: kelola aturan, generator lokal, konfirmasi pending
- [ ] Laporan: per kategori, sumber income, tren, perbandingan, selisih tidak tercatat
- [ ] Export CSV/PDF (minta persetujuan library dulu)

### iOS
- [ ] Semua item Flutter Fase 3 dengan padanan iOS

## Fase 4 — Pengembangan (belum dijadwalkan)

- [ ] Target tabungan
- [ ] Budget per kategori
- [ ] Shared budget (pasangan/keluarga)
- [ ] Versi web + endpoint REST per entitas
- [ ] Crash reporting
