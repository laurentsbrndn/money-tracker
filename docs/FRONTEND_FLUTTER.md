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
| Export PDF | `pdf` (font bawaan Helvetica, teks Latin) |
| Berbagi file | `share_plus`; file sementara lewat `path_provider` (CSV ditulis manual, tanpa paket `csv`) |
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
    │   │   ├── recurrence.dart       # kemunculan berulang + nextOccurrence
    │   │   └── report.dart           # laporan: per kategori/sumber, tren, perbandingan, selisih tidak tercatat
    │   ├── billing/
    │   │   ├── billing_service.dart  # satu-satunya pemakai SDK RevenueCat: logIn/logOut, offerings, purchase, restore
    │   │   ├── billing_failure.dart  # jenis kegagalan toko → pesan Indonesia
    │   │   ├── paywall_package.dart  # paket yang ditampilkan paywall (tanpa tipe SDK)
    │   │   ├── billing_providers.dart  # sinkron logIn/logOut dengan sesi + kirim ulang perubahan yang ditolak plan
    │   │   ├── entitlement_info.dart / entitlement_provider.dart  # sync_state.entitlement + toleransi offline 3 hari
    │   │   ├── entitlement_repository.dart  # GET /v1/me/entitlements → sync_state.entitlement
    │   │   └── logic/entitlement_polling.dart  # polling server setelah pembelian (murni)
    │   ├── notifications/
    │   │   ├── notification_service.dart
    │   │   └── notification_scheduler.dart
    │   ├── security/
    │   │   └── app_lock_controller.dart
    │   ├── platform/
    │   │   └── external_links.dart   # buka URL/halaman Play lewat method channel MainActivity (tanpa url_launcher)
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
        ├── export/
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

- Penanda "sedang dikirim" outbox = kolom `batch_id` (`SYNC_PROTOCOL.md` §5.2.1). Task background dilewati selama `sync_state.foreground_since` segar (lebih baru dari 3 menit): app menulis ulang nilainya tiap 60 detik (heartbeat) selama foreground dan menghapusnya saat pause, jadi crash atau force-stop paling lama memblokir task 3 menit. Tujuannya supaya dua isolate tidak me-refresh token bersamaan.
- `Workmanager().registerPeriodicTask` 30 menit, constraint `NetworkType.connected`. Callback background membuka database sendiri (isolate terpisah) lalu menjalankan `SyncEngine.runOnce()`.
- Pemicu foreground: `AppLifecycleListener.onResume`, `connectivity_plus`, debounce 2 detik setelah tulis.
- `SyncBadge` di header Dashboard membaca `sync_status_provider`: `Tersinkron`, `Menunggu sync (n)`, `Offline`, `Perlu login`, `Perlu perhatian (n)`.

### 4.4 Billing

- Setelah login: `Purchases.logIn(userId)`. Setelah logout: `Purchases.logOut()`.
- Paywall dibuat sendiri (bukan template RevenueCat) dengan paket dari `Offerings.current`.
- Setelah pembelian sukses: panggil `GET /v1/me/entitlements`, simpan ke `sync_state.entitlement`, lalu buka fitur. Status premium **tidak** diambil dari `CustomerInfo` RevenueCat untuk logika fitur, karena server adalah sumber kebenaran.
- Webhook RevenueCat ke server bisa terlambat, jadi setelah pembelian atau pemulihan app menampilkan "memproses" dan memanggil `GET /v1/me/entitlements` berulang (jeda 1, 2, 3, 4 lalu 5 detik) sampai server melaporkan `premium = true` atau 30 detik lewat (restore: 15 detik). Habis waktu → pesan "pembayaran diterima, aktivasi belum selesai" dengan tombol "Periksa lagi"; pembelian tidak perlu diulang.
- SDK dikonfigurasi di `bootstrap()` dengan `appUserID` = user yang sedang masuk (bila ada), sehingga pembelian tidak dimulai dengan ID anonim. Tanpa `REVENUECAT_ANDROID_KEY` SDK tidak dijalankan dan paywall menampilkan "belum tersedia".
- Premium dibaca dari `sync_state.entitlement` (pull `meta.entitlement` atau `GET /v1/me/entitlements`): aktif bila `premium = true` dan sekarang belum melewati `expires_at` + 3 hari. User non-premium selalu `expires_at = null`. Saat server mulai melaporkan premium, perubahan yang sebelumnya ditolak `plan_limit` dikirim ulang otomatis.

### 4.5 Notifikasi

Semua lokal, dijadwalkan ulang setiap app dibuka dan setelah pull: pengingat harian, cocokkan saldo, peringatan budget (dihitung dari `domain_rules`), konfirmasi transaksi berulang, evaluasi bulan.

### 4.6 UI

- Material 3, mode terang dan gelap.
- Nominal: income hijau, expense merah, transfer abu-abu; dengan `hide_amounts` aktif nominal tampil `Rp •••••`.
- Input nominal dengan numpad besar di form transaksi.
- Semua layar punya empty state, loading, dan error state.

### 4.7 Export CSV/PDF

Hanya premium (BUSINESS_RULES §7); layar dan controller sama-sama memeriksa `isPremium`. Data dibaca dari Drift lokal tanpa endpoint; hanya transaksi `posted` yang belum dihapus (pending dan tombstone tidak ikut). Aturan berikut dipakai **identik di iOS**:

| Hal | Aturan |
| --- | --- |
| Periode | Pintasan "Bulan ini" (default), "Bulan lalu", "3 bulan terakhir" (bulan berjalan + 2 bulan sebelumnya), "Tahun ini", "Semua data", atau tanggal awal/akhir bebas; awal tidak boleh setelah akhir. Tanggal = tanggal sipil di timezone pengguna (`UserClock`) |
| Kolom CSV | `Tanggal` (YYYY-MM-DD), `Tipe`, `Jumlah (Rp)` (bilangan bulat; adjustment bertanda), `Akun`, `Akun tujuan`, `Kategori`, `Catatan`; urut tanggal naik. Satu file berapa pun barisnya |
| Format CSV | UTF-8 dengan BOM, baris akhir CRLF, escaping RFC 4180. Sel teks yang diawali `=`, `+`, `-`, `@`, tab, atau CR diberi awalan `'`; kolom jumlah tidak (tetap angka) |
| Pemisah CSV | Pilihan "Otomatis / Koma / Titik koma". Otomatis: `;` bila pemisah desimal locale perangkat adalah koma (id-ID, sebagian besar Eropa), `,` bila titik (en-US). Aturan ada di satu fungsi `resolveCsvDelimiter` |
| PDF | Ringkasan periode (income, expense, selisih, jumlah transaksi) di halaman pertama, tabel transaksi dipaginasi (26 baris di halaman pertama, 36 sesudahnya), `Rp 25.000`. Dibuat halaman demi halaman dengan indikator proses; font bawaan (karakter di luar Latin-1 tampil `?`) |
| Periode kosong | Pesan "Tidak ada transaksi pada periode ini", file tidak dibuat |
| Privasi | Nominal asli diexport walau "Sembunyikan nominal" aktif, tetapi tidak saat app terkunci (diperiksa sebelum menulis dan sebelum berbagi) |
| File sementara | `<temp>/exports/money-tracker_<awal>_<akhir>.<csv atau pdf>` (Semua data: tanggal transaksi pertama dan terakhir). Dihapus saat app mulai dan sebelum export berikutnya; juga segera setelah berbagi bila platform melaporkan hasilnya (di Android hasil berbagi tidak dilaporkan, jadi file menunggu salah satu dari dua kejadian tadi, supaya app tujuan masih sempat membacanya) |

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
| `/more/export` | Export CSV/PDF (premium; non-premium melihat ajakan ke paywall) | 3 |
| `/more/recurring`, `/more/recurring/new`, `/more/recurring/:id` | Transaksi berulang: daftar, aturan baru (bisa diisi dari form transaksi lewat "Jadikan berulang"), ubah | 3 |
| `/more/subscription`, `/paywall` | Langganan & paywall (`/paywall?restore=1` langsung memulihkan pembelian) | 3 |
| `/more/settings/*` | Profil, sinkronisasi, data, hapus akun | 1–3 |
| `/more/settings/preferences` | Preferensi: timezone, hari pertama minggu, tema | 2 |
| `/more/settings/security` | Keamanan: PIN, biometrik, kunci otomatis, sembunyikan nominal | 2 |
| `/more/settings/security/pin` | Atur, ubah, atau matikan PIN | 2 |
| `/more/settings/notifications` | Notifikasi: pengingat harian, cocokkan saldo, peringatan budget | 2 |
| `/upgrade-required` | Perbarui aplikasi (`426`) | 1 |

**Layar kunci bukan route.** Kunci PIN/biometrik adalah overlay di atas seluruh app (`LockGate` membungkus root app), jadi ikut menutup dialog dan bottom sheet yang sedang terbuka dan tidak memengaruhi stack navigasi. Karena itu tidak ada route `/lock`.

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
  "TERMS_URL": "",
  "PRIVACY_URL": "",
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

## 9. Catatan implementasi Fase 3

| Hal | Keputusan |
| --- | --- |
| Paket | `purchases_flutter`, `fl_chart`, `pdf`, dan `share_plus` (dijadwalkan di §1); membuka URL (syarat, privasi, kelola langganan Play) lewat method channel kecil di `MainActivity` |
| `TERMS_URL` / `PRIVACY_URL` | `--dart-define` baru; kosong menyembunyikan tautan di paywall |
| Laporan | Dihitung **lokal** dari database (`domain_rules/report.dart`), sesuai `API.md` §5 dan `APP_FLOWS.md` Flow 8; endpoint `GET /v1/reports/*` tidak dipakai app. Bulan lebih dari 2 bulan ke belakang, tren, perbandingan, dan selisih tidak tercatat terkunci untuk free (paywall). Ketuk irisan/batang membuka daftar transaksi dengan filter yang sesuai |
| Grafik dan "Sembunyikan nominal" | Sumbu nilai dan tooltip tidak menampilkan nominal; legenda memperlihatkan persentase, bukan nominal |
| Transaksi berulang | Occurrence dibuat app saat gate `ready`, saat kembali ke foreground, setelah pull mengubah aturan, dan saat premium menyala; ID = UUIDv5(`rule_id|YYYY-MM-DD`); baris yang sudah ada (juga yang dihapus, juga yang dibuat cron server) dilewati. Aturan yang akun/kategorinya sudah dihapus tidak menghasilkan transaksi tetapi `last_generated_date` tetap dimajukan, seperti server |
| Pause oleh server | `is_paused = true` dari pull ditampilkan "Dijeda: Premium berakhir" bila server tidak melaporkan premium; melanjutkan aturan butuh premium (`plan_limit` ditolak di client dan server) |
| Konfirmasi | Transaksi `pending_confirmation` tidak ikut daftar riwayat; tampil di bagian "Menunggu konfirmasi" (Catat / Lewati). Menyimpan form sebuah transaksi pending juga mencatatnya. Notifikasi lokal "menunggu konfirmasi" dikirim saat app membuat yang baru |
| Export CSV/PDF | Lihat §4.7. Paket `pdf` dan `share_plus` disetujui; `share_plus` menarik `url_launcher_*` sebagai dependensi transitif (bukan dependensi langsung). `path_provider` sudah ada |

