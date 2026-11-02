# CLAUDE.md — Money Tracker

File ini dibaca otomatis oleh Claude Code di setiap sesi. Isinya aturan kerja proyek. Detail teknis ada di folder `docs/`.

## Ringkasan proyek

Aplikasi money tracker pribadi yang **offline-first**:

- Mencatat income, expense, transfer antar akun, dan adjustment.
- Menampilkan ringkasan bulanan, saldo aktual per akun (bank/e-wallet/savings vs cash), selisih antara catatan dan saldo asli (rekonsiliasi), serta budget goal needs/wants/savings.
- Ada fitur premium berbasis subscription (RevenueCat).

| Bagian | Stack | Folder |
| --- | --- | --- |
| Backend | Go 1.26 + Fiber v3 + GORM, modular monolith, deploy di Vercel | `backend/` |
| Database | PostgreSQL 17 di Neon | – |
| Android | Flutter (channel stable) + Drift (SQLite/SQLite3MultipleCiphers) + Riverpod, minimal Android 10 (API 29) | `app_android/` |
| iOS | SwiftUI + GRDB + Observation, project via XcodeGen, minimal iOS 18 | `app_ios/` |
| Kontrak | OpenAPI 3.1 + contoh perhitungan JSON (acuan) | `contracts/` |

## Peta repo

```
money-tracker/
├── CLAUDE.md
├── docs/
│   ├── ARCHITECTURE.md      # gambaran sistem, aturan modul, deployment
│   ├── APP_FLOWS.md         # alur layar dari onboarding sampai hapus akun
│   ├── DATA_MODEL.md        # semua tabel server + kolom + index
│   ├── SYNC_PROTOCOL.md     # protokol push/pull offline-first
│   ├── BUSINESS_RULES.md    # rumus, aturan bisnis, edge case, contoh perhitungan
│   ├── API.md               # daftar endpoint + format request/response
│   ├── BACKEND.md           # spec Go Fiber + struktur folder
│   ├── FRONTEND_FLUTTER.md  # spec Flutter Android + struktur folder
│   ├── FRONTEND_IOS.md      # spec SwiftUI iOS + struktur folder
│   └── ROADMAP.md           # fase kerja + checklist progres
├── contracts/
│   ├── openapi.yaml         # sumber kebenaran API
│   └── fixtures/            # contoh perhitungan JSON (data acuan, bukan file test)
├── backend/
├── app_android/
└── app_ios/
```

## Dokumen mana yang dibaca

| Sedang mengerjakan | Wajib baca |
| --- | --- |
| Apa pun, sesi pertama | `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` |
| Backend | `docs/BACKEND.md`, `docs/DATA_MODEL.md`, `docs/API.md` |
| Sync (server atau client) | `docs/SYNC_PROTOCOL.md` |
| Perhitungan saldo, budget, laporan | `docs/BUSINESS_RULES.md` |
| Layar / UX | `docs/APP_FLOWS.md` |
| Flutter | `docs/FRONTEND_FLUTTER.md` + dokumen lintas platform di atas |
| iOS | `docs/FRONTEND_IOS.md` + dokumen lintas platform di atas |

## Aturan wajib

### Git

- **Jangan pernah** menjalankan `git commit`, `git push`, `git merge`, `git rebase`, `git reset`, `git stash`, `git checkout`, atau membuat/menghapus branch. Semua operasi git dilakukan manual oleh user.
- Yang boleh hanya perintah baca: `git status`, `git diff`, `git log`.
- Jangan membuat GitHub Actions yang auto-commit atau auto-push.

### Cara kerja

1. Kerjakan **satu fase** dari `docs/ROADMAP.md` dalam satu waktu, dan di dalamnya **satu platform** sesuai urutan: backend → Flutter → iOS. Jangan lompat fase.
2. Sebelum menulis kode di tugas yang besar, tunjukkan rencana singkat (file yang akan dibuat/diubah) dan tunggu persetujuan.
3. Dokumen di `docs/` adalah sumber kebenaran. Kalau implementasi perlu menyimpang, **berhenti dan tanyakan dulu**, lalu perbarui dokumennya setelah disetujui.
4. Jangan menambah fitur, library, atau endpoint yang tidak ada di dokumen tanpa persetujuan.
5. Kalau ada yang ambigu, tanyakan. Jangan menebak aturan bisnis.
6. Setelah satu bagian selesai: centang item di `docs/ROADMAP.md`, lalu laporkan ringkasan perubahan beserta daftar path file yang dibuat/diubah.

### Konvensi kode

- **Satu model per file.** Satu struct entity Go, satu tabel Drift, satu record GRDB per file. Tidak boleh beberapa entity dalam satu file.
- **Migration database = satu file**: `backend/migrations/migrations.go` (gormigrate). Migration baru ditambahkan sebagai entri baru di file yang sama. Migration yang sudah dijalankan tidak boleh diubah.
- **Hindari raw SQL.** Pakai GORM Migrator API dan query builder GORM. Pengecualian yang diizinkan tercantum di `docs/BACKEND.md` bagian "Pengecualian raw SQL".
- Jangan pernah memakai `AutoMigrate` saat server start.
- **Uang selalu integer** (`int64` / `int` / `Int64`) dalam rupiah. Dilarang `float`/`double`/`Decimal` untuk nominal.
- **Tanggal transaksi** adalah tanggal kalender (`YYYY-MM-DD`), bukan timestamp. Timestamp selalu UTC RFC 3339.
- **ID** semua entitas yang disinkron = UUIDv7 yang dibuat client. Pengecualian ID deterministik ada di `docs/SYNC_PROTOCOL.md`.
- Contract-first: perubahan API dimulai dari `contracts/openapi.yaml`, lalu client di-generate ulang.
- Rumus di `docs/BUSINESS_RULES.md` diimplementasikan **identik** di backend, Flutter, dan iOS. Hasilnya harus sama dengan contoh di `BUSINESS_RULES.md` §9.3 (`contracts/fixtures/business_rules/01_monthly_basic.json`).
- Identifier, komentar kode, dan pesan log dalam bahasa Inggris. Teks UI dalam bahasa Indonesia. Dokumen dalam bahasa Indonesia.
- Secret tidak boleh ditulis di kode. Hanya `.env.example` (nilai kosong/placeholder) yang boleh ada di repo.

### Versi framework dan library

- Selalu pakai rilis **stable**. Dilarang versi beta, rc, dev, preview, atau channel non-stable.
- Versi dikunci lewat lockfile (`go.sum`, `pubspec.lock`, `Package.resolved`). Jangan upgrade versi major tanpa persetujuan user.

| Komponen | Versi |
| --- | --- |
| Go | 1.26, patch terbaru (`go 1.26` + `toolchain go1.26.<patch>` di `go.mod`) |
| Fiber | v3, rilis stabil terbaru (v2 sudah deprecated) |
| GORM | v1, rilis stabil terbaru |
| PostgreSQL (Neon) | 17 |
| Flutter / Dart | Channel stable terbaru; versi dicatat di `pubspec.yaml` (`environment`) |
| Android | `minSdk 29` (Android 10); `targetSdk`/`compileSdk` mengikuti syarat Google Play terbaru |
| Xcode / Swift | Xcode stabil terbaru, Swift 6 |
| iOS | Deployment target 18.0 |
| Library lain | Rilis stabil terbaru saat pertama ditambahkan |

### Testing

- **Jangan membuat file test apa pun**: tidak ada `*_test.go`, folder `backend/test/`, folder `app_android/test/`, maupun target `MoneyTrackerTests`. Termasuk tidak memasang library khusus test. User melakukan pengujian sendiri.
- Verifikasi yang tetap dilakukan setelah setiap kelompok kerja hanya: build/compile berhasil dan linter/analyzer bersih.
- Bila user meminta test secara eksplisit, buat hanya yang diminta.

## Perintah

```bash
# Backend (dari folder backend/)
go run ./cmd/api                 # jalankan server lokal (PORT default 8080)
go run ./cmd/migrate up          # jalankan migration (pakai DATABASE_URL_DIRECT)
go vet ./... && golangci-lint run

# Flutter (dari folder app_android/)
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze

# iOS (dari folder app_ios/)
xcodegen generate
xcodebuild -scheme MoneyTracker -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Nama simulator disesuaikan dengan yang tersedia (`xcrun simctl list devices`).

## Definition of done

Sebuah tugas dianggap selesai bila:

- [ ] Build/compile berhasil dan linter/analyzer bersih untuk platform terkait.
- [ ] Tidak ada file test yang dibuat (kecuali user memintanya).
- [ ] Versi framework dan library sesuai bagian "Versi framework dan library".
- [ ] Tidak ada TODO tanpa penjelasan, tidak ada secret di kode.
- [ ] Dokumen diperbarui bila ada keputusan baru yang sudah disetujui user.
- [ ] Item terkait di `docs/ROADMAP.md` dicentang.
- [ ] Ringkasan + daftar file yang berubah dilaporkan ke user.
