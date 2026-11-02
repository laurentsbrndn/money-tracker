# Frontend Android — Flutter

App Flutter ini **khusus Android**. iOS dibuat terpisah dengan SwiftUI (`FRONTEND_IOS.md`). Baca juga `SYNC_PROTOCOL.md` dan `BUSINESS_RULES.md`; keduanya mengikat app ini.

## 1. Stack

| Kebutuhan | Package |
| --- | --- |
| Flutter / Dart | Channel **stable** terbaru; versi dicatat di `pubspec.yaml` (`environment.sdk` dan `environment.flutter`) |
| Android | `minSdk 29` (Android 10); `targetSdk`/`compileSdk` mengikuti syarat Google Play terbaru |
| State management + DI | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` |
| Navigasi | `go_router` (`StatefulShellRoute` untuk tab bawah) |
| Database lokal | `drift`, `drift_dev`, `sqlite3` (build hook `sqlite3mc` untuk enkripsi), `path_provider` |
| HTTP | `dio` |
| Client API | `swagger_parser` (generate dari `contracts/openapi.yaml`, output `retrofit` + `json_serializable`), `retrofit` |
| Model immutable | `freezed`, `json_serializable` |
| Secure storage | `flutter_secure_storage` |
| Konektivitas | `connectivity_plus` |
| Background sync | `workmanager` |
| Notifikasi lokal | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| Biometrik | `local_auth` |
| Login Google | `google_sign_in` (Credential Manager; `serverClientId` = web client ID) |
| Subscription | `purchases_flutter` (RevenueCat) |
| Grafik | `fl_chart` |
| UUID v7/v5 | `uuid` |
| Format angka/tanggal | `intl` |
| Info app/device | `package_info_plus`, `device_info_plus` |
| Lokalisasi | `flutter_localizations` + gen-l10n (`app_id.arb`) |
| Lint | `flutter_lints` + aturan tambahan di `analysis_options.yaml` |

Jangan memasang `sqlite3_flutter_libs` maupun `sqlcipher_flutter_libs` (end-of-life); enkripsi lewat SQLite3MultipleCiphers dari build hook `sqlite3`. Semua package memakai rilis stabil terbaru (bukan prerelease/dev), dikunci di `pubspec.lock`. Library lain butuh persetujuan user.

## 2. Struktur folder

```
app_android/
├── pubspec.yaml
├── analysis_options.yaml
├── build.yaml
├── swagger_parser.yaml               # input ../contracts/openapi.yaml → lib/core/network/generated/
├── l10n.yaml
├── android/                          # applicationId diisi user (misal com.<nama>.moneytracker)
├── assets/
│   ├── logos/                        # logo bank & e-wallet (provider_key.png)
│   └── icons/
└── lib/
    ├── main.dart                     # ensureInitialized → bootstrap()
    ├── bootstrap.dart                # init DB, timezone, RevenueCat, Workmanager, ProviderScope
    ├── app.dart                      # MaterialApp.router + theme + l10n
    ├── l10n/
    │   └── app_id.arb
    ├── core/
    │   ├── config/
    │   │   └── app_config.dart       # --dart-define: API_BASE_URL, REVENUECAT_ANDROID_KEY, GOOGLE_SERVER_CLIENT_ID
    │   ├── database/
    │   │   ├── app_database.dart     # @DriftDatabase + schemaVersion + MigrationStrategy (satu tempat migration lokal)
    │   │   ├── connection.dart       # buka SQLite3MultipleCiphers, kunci dari secure storage
    │   │   ├── converters/
    │   │   │   └── civil_date_converter.dart
    │   │   ├── tables/               # SATU tabel per file
    │   │   │   ├── sync_columns.dart         # mixin kolom bersama tabel sync (id, created_at, updated_at, deleted_at, server_version, sync_status); bukan tabel
    │   │   │   ├── user_settings_table.dart
    │   │   │   ├── accounts_table.dart
    │   │   │   ├── balance_snapshots_table.dart
    │   │   │   ├── categories_table.dart
    │   │   │   ├── transactions_table.dart
    │   │   │   ├── recurring_rules_table.dart
    │   │   │   ├── budget_goals_table.dart
    │   │   │   ├── outbox_table.dart
    │   │   │   └── sync_state_table.dart
    │   │   └── daos/                 # satu DAO per tabel
    │   ├── network/
    │   │   ├── dio_factory.dart
    │   │   ├── api_client_provider.dart
    │   │   ├── api_exception.dart    # problem+json → ApiException(code, detail, fields)
    │   │   ├── interceptors/
    │   │   │   ├── client_info_interceptor.dart   # X-Device-ID, X-Platform, X-App-Version, X-Request-ID
    │   │   │   ├── auth_interceptor.dart          # Bearer + refresh single-flight saat token_expired
    │   │   │   └── problem_interceptor.dart
    │   │   └── generated/            # output swagger_parser — JANGAN diedit manual
    │   ├── auth/
    │   │   ├── token_storage.dart
    │   │   ├── session_state.dart
    │   │   └── session_controller.dart
    │   ├── sync/
    │   │   ├── sync_engine.dart      # siklus SYNC_PROTOCOL.md §7, single-flight
    │   │   ├── outbox_writer.dart    # tulis entitas + outbox dalam satu transaksi (§6)
    │   │   ├── push_applier.dart     # §8.4
    │   │   ├── pull_applier.dart     # §9.4
    │   │   ├── entity_codec.dart     # baris Drift ↔ JSON snake_case
    │   │   ├── sync_scheduler.dart   # debounce, foreground, konektivitas, Workmanager
    │   │   └── sync_status_provider.dart
    │   ├── domain_rules/             # port 1:1 dari BUSINESS_RULES.md, murni Dart
    │   │   ├── types.dart            # tipe nilai murni (Account, Transaction, BalanceSnapshot, BudgetGoal + enum)
    │   │   ├── rounding.dart
    │   │   ├── period.dart
    │   │   ├── balance.dart
    │   │   ├── reconciliation.dart
    │   │   ├── budget.dart
    │   │   └── recurrence.dart
    │   ├── billing/
    │   │   ├── billing_service.dart  # RevenueCat logIn/logOut, offerings, purchase, restore
    │   │   └── entitlement_provider.dart  # dari sync_state.entitlement + toleransi offline 3 hari
    │   ├── notifications/
    │   │   ├── notification_service.dart
    │   │   └── notification_scheduler.dart
    │   ├── security/
    │   │   └── app_lock_controller.dart
    │   ├── ids/
    │   │   └── id_generator.dart     # v7 + v5 dengan namespace dari SYNC_PROTOCOL.md §3
    │   ├── money/
    │   │   ├── money_formatter.dart  # 25000 → "Rp 25.000"
    │   │   └── money_input_formatter.dart
    │   ├── time/
    │   │   ├── civil_date.dart       # tanggal kalender tanpa jam
    │   │   └── user_clock.dart       # "hari ini" di timezone user
    │   ├── router/
    │   │   ├── app_router.dart
    │   │   └── route_paths.dart
    │   ├── theme/
    │   │   ├── app_theme.dart
    │   │   ├── app_colors.dart
    │   │   ├── category_icons.dart   # key icon → IconData
    │   │   └── provider_logos.dart   # provider_key → asset
    │   └── widgets/                  # komponen bersama (AmountText, EmptyState, SyncBadge, dll.)
    └── features/
        ├── auth/
        ├── onboarding/
        ├── dashboard/
        ├── transactions/
        ├── accounts/
        ├── reconciliation/
        ├── budget/
        ├── categories/
        ├── reports/
        ├── recurring/
        ├── subscription/
        └── settings/
```

Isi setiap folder fitur:

```
features/<fitur>/
├── data/            # <fitur>_repository.dart: baca dari DAO (stream), tulis lewat OutboxWriter
├── domain/          # model freezed untuk UI (satu model per file)
├── application/     # Riverpod notifier/provider (state + aksi)
└── presentation/
    ├── screens/
    └── widgets/
```

## 3. Aturan arsitektur

1. **UI → application → data → database lokal.** Widget tidak pernah memanggil DAO, Dio, atau RevenueCat secara langsung.
2. Semua data domain dibaca sebagai `Stream` dari Drift (`watch()`), sehingga UI otomatis ter-update setelah tulis lokal maupun pull.
3. Semua tulis data domain lewat `OutboxWriter` (satu transaksi Drift: baris + outbox), lalu memicu `SyncScheduler.requestSync()`.
4. Endpoint online-only (auth, `DELETE /me`, entitlement) dipanggil dari repository fitur terkait, bukan dari widget.
5. Rumus hanya dari `core/domain_rules/`. Tidak boleh menghitung saldo/budget di widget atau repository.
6. Semua query UI memfilter `deleted_at IS NULL`.
7. Uang `int`, tanggal transaksi `CivilDate`. Tidak ada `double` untuk nominal.
8. Migration database lokal hanya di `app_database.dart` (`MigrationStrategy.onUpgrade` dengan langkah per `schemaVersion`).
9. Teks UI dari `app_id.arb`, tidak di-hardcode di widget.

## 4. Detail teknis

### 4.1 Database terenkripsi

- Saat pertama dijalankan, buat kunci acak 32 byte, simpan di `flutter_secure_storage` (Android Keystore).
- Buka database dengan `NativeDatabase.createInBackground(file, setup: (db) => db.execute("PRAGMA key = '…'"))` dengan build hook di `pubspec.yaml` (`hooks: user_defines: sqlite3: source: sqlite3mc`). Sebelum `PRAGMA key`, verifikasi `PRAGMA cipher;` mengembalikan baris (bukan hanya `assert`: bila kosong, lempar error agar database tidak pernah terbuka tanpa enkripsi). Tanggal/timestamp disimpan sebagai teks (`store_date_time_values_as_text` di `build.yaml`).
- Logout: tutup database, hapus file, hapus kunci.

### 4.2 Auth

- Token di `flutter_secure_storage`. Access token juga di-cache di memori.
- `auth_interceptor`: saat respons `401 token_expired`, jalankan refresh **sekali** (request lain menunggu hasil yang sama), lalu ulangi request. `refresh_invalid`/`refresh_reused` → `SessionState.needsLogin` tanpa menghapus database.
- Login Android: email + password, dan Google. Sign in with Apple tidak ditampilkan di Android.

### 4.3 Sync

Implementasi persis `SYNC_PROTOCOL.md`. Tambahan khusus Android:

- `Workmanager().registerPeriodicTask` 30 menit, constraint `NetworkType.connected`. Callback background membuka database sendiri (isolate terpisah) lalu menjalankan `SyncEngine.runOnce()`.
- Pemicu foreground: `AppLifecycleListener.onResume`, `connectivity_plus`, debounce 2 detik setelah tulis.
- `SyncBadge` di header Dashboard membaca `sync_status_provider`: `Tersinkron`, `Menunggu sync (n)`, `Offline`, `Perlu login`, `Perlu perhatian (n)`.

### 4.4 Billing

- Setelah login: `Purchases.logIn(userId)`. Setelah logout: `Purchases.logOut()`.
- Paywall dibuat sendiri (bukan template RevenueCat) dengan paket dari `Offerings.current`.
- Setelah pembelian sukses: panggil `GET /v1/me/entitlements`, simpan ke `sync_state.entitlement`, lalu buka fitur. Status premium **tidak** diambil dari `CustomerInfo` RevenueCat untuk logika fitur, karena server adalah sumber kebenaran.

### 4.5 Notifikasi

Semua lokal, dijadwalkan ulang setiap app dibuka dan setelah pull: pengingat harian, cocokkan saldo, peringatan budget (dihitung dari `domain_rules`), konfirmasi transaksi berulang, evaluasi bulan.

### 4.6 UI

- Material 3, mode terang dan gelap.
- Nominal: income hijau, expense merah, transfer abu-abu; dengan `hide_amounts` aktif nominal tampil `Rp •••••`.
- Input nominal dengan numpad besar di form transaksi.
- Semua layar punya empty state, loading, dan error state.

## 5. Navigasi dan layar

Tab bawah: **Beranda · Transaksi · Akun · Budget · Lainnya**.

| Route | Layar | Fase |
| --- | --- | --- |
| `/splash` | Cek sesi & database | 1 |
| `/onboarding` | 3 slide intro | 1 |
| `/auth/login`, `/auth/register` | Login / daftar (email, Google) | 1 |
| `/auth/verify-email` | Input kode 6 digit | 1 |
| `/auth/forgot-password`, `/auth/reset-password` | Lupa & reset password | 1 |
| `/setup` | Wizard: saldo Cash, tambah akun, goal, kategori, notifikasi | 1 (goal & notifikasi di fase 2) |
| `/initial-sync` | "Menyiapkan data…" | 1 |
| `/home` | Dashboard | 1 (kartu uang aktual, selisih, budget di fase 2) |
| `/transactions` | Daftar + filter + cari | 1 |
| `/transactions/new?type=`, `/transactions/:id` | Form expense/income/transfer | 1 |
| `/accounts`, `/accounts/new`, `/accounts/:id` | Daftar, form, detail akun | 1 |
| `/reconcile` | Cocokkan saldo | 2 |
| `/budget`, `/budget/goal` | Halaman budget, atur goal | 2 |
| `/more` | Menu Lainnya | 1 |
| `/more/categories` | Kelola kategori | 1 |
| `/more/reports` | Laporan | 3 |
| `/more/recurring` | Transaksi berulang | 3 |
| `/more/subscription`, `/paywall` | Langganan & paywall | 3 |
| `/more/settings/*` | Profil, preferensi, keamanan, notifikasi, sinkronisasi, data, hapus akun | 1–3 |
| `/lock` | Layar kunci PIN/biometrik | 2 |
| `/upgrade-required` | Perbarui aplikasi (`426`) | 1 |

Alur detail setiap layar ada di `APP_FLOWS.md`.

## 6. Build & environment

```bash
flutter run --dart-define-from-file=env/dev.json
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

`env/dev.json` dan `env/prod.json` tidak masuk repo; sediakan `env/example.json`:

```json
{
  "API_BASE_URL": "http://10.0.2.2:8080",
  "REVENUECAT_ANDROID_KEY": "",
  "GOOGLE_SERVER_CLIENT_ID": ""
}
```

`10.0.2.2` adalah alamat host dari emulator Android.

## 7. Target perangkat & performa

Tujuannya: app lancar di HP Android kelas bawah (RAM 2–3 GB) yang menjalankan Android 10 ke atas.

- `minSdk 29`. Di Android 10+ Flutter memakai renderer Impeller secara default, sehingga rendering lebih konsisten.
- Rilis sebagai App Bundle (`flutter build appbundle`) supaya Play Store hanya mengirim kode untuk ABI device. Aktifkan R8 (`minifyEnabled`, `shrinkResources`) dan `--obfuscate --split-debug-info`.
- Daftar panjang memakai `ListView.builder`/`SliverList` dengan paging dari Drift, bukan memuat semua transaksi sekaligus.
- Pakai widget `const` sebanyak mungkin; hindari animasi berat, blur, dan shadow berlapis.
- Logo dan ikon berukuran kecil (logo provider ≤ 96×96 px, format WebP/PNG terkompresi).
- Query Drift memakai index yang sama dengan server (tanggal dan akun) dan hanya meng-observe data bulan yang sedang tampil.
- Grafik laporan hanya dirender saat layar laporan dibuka.

## 8. Testing

Tidak ada file test (lihat `CLAUDE.md`). Verifikasi otomatis cukup `flutter analyze` dan build berhasil.
