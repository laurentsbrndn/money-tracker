# Frontend iOS — SwiftUI

App iOS native dengan SwiftUI. Perilaku harus setara dengan app Android (`FRONTEND_FLUTTER.md`). Baca juga `SYNC_PROTOCOL.md`, `BUSINESS_RULES.md`, dan `APP_FLOWS.md`.

## 1. Stack

| Kebutuhan | Pilihan |
| --- | --- |
| Bahasa | Swift 6 dengan strict concurrency |
| Target minimum | iOS 18.0 (deployment target) |
| Toolchain | Xcode stabil terbaru |
| UI | SwiftUI, `NavigationStack`, `TabView` |
| State | Observation (`@Observable`), `@MainActor` untuk ViewModel |
| Database lokal | GRDB (SPM `groue/GRDB.swift`), `DatabasePool` mode WAL |
| Client API | `apple/swift-openapi-generator` (build plugin) + `swift-openapi-runtime` + `swift-openapi-urlsession` |
| Secure storage | Keychain via wrapper sendiri (`Security` framework), tanpa library |
| Login | `AuthenticationServices` (Sign in with Apple), `google/GoogleSignIn-iOS` |
| Subscription | `RevenueCat/purchases-ios` |
| Grafik | Swift Charts |
| Background | `BackgroundTasks` (`BGAppRefreshTask`) |
| Notifikasi | `UserNotifications` |
| Biometrik | `LocalAuthentication` |
| Konektivitas | `Network` (`NWPathMonitor`) |
| Project | XcodeGen (`project.yml`), file `.xcodeproj` tidak diedit manual |
| Format | `swift-format` |

Semua package SPM memakai rilis stabil terbaru (bukan beta), dikunci di `Package.resolved`, dengan aturan versi `upToNextMajor`. Library lain butuh persetujuan user.

## 2. Struktur folder

```
app_ios/
├── project.yml                         # XcodeGen: target, SPM packages, build settings, plugin OpenAPI
├── .swift-format
├── Config/
│   ├── Base.xcconfig
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Secrets.example.xcconfig        # API_BASE_URL, REVENUECAT_IOS_KEY, GOOGLE_IOS_CLIENT_ID, GOOGLE_IOS_REVERSED_CLIENT_ID
│   └── Secrets.xcconfig                # tidak masuk repo
└── MoneyTracker/
    ├── App/
    │   ├── MoneyTrackerApp.swift       # @main, inject AppContainer ke environment
    │   ├── AppDelegate.swift           # registrasi BGTask, notifikasi, GoogleSignIn URL
    │   ├── AppContainer.swift          # composition root (database, API, sync, billing, repositories)
    │   ├── RootView.swift              # splash / onboarding / auth / main / lock / upgrade
    │   ├── MainTabView.swift
    │   └── AppRouter.swift             # path per tab (NavigationPath)
    ├── Core/
    │   ├── Config/
    │   │   └── AppConfig.swift         # baca nilai xcconfig dari Info.plist
    │   ├── Database/
    │   │   ├── AppDatabase.swift       # buka DatabasePool + file protection
    │   │   ├── DatabaseMigrations.swift  # SATU file migration lokal (DatabaseMigrator)
    │   │   ├── CivilDate+GRDB.swift    # CivilDate ↔ TEXT "YYYY-MM-DD" (CivilDate sendiri murni Foundation)
    │   │   ├── UTCMillisDateStrategy.swift  # Date ↔ TEXT RFC 3339 UTC dengan milidetik, lebar tetap
    │   │   ├── Records/                # SATU record per file
    │   │   │   ├── UserSettingsRecord.swift
    │   │   │   ├── AccountRecord.swift
    │   │   │   ├── BalanceSnapshotRecord.swift
    │   │   │   ├── CategoryRecord.swift
    │   │   │   ├── TransactionRecord.swift
    │   │   │   ├── RecurringRuleRecord.swift
    │   │   │   ├── BudgetGoalRecord.swift
    │   │   │   ├── OutboxRecord.swift
    │   │   │   └── SyncStateRecord.swift
    │   │   └── Queries/                # request & ValueObservation per entitas
    │   ├── Networking/
    │   │   ├── openapi.yaml            # symlink → ../../../../contracts/openapi.yaml
    │   │   ├── openapi-generator-config.yaml   # generate: types, client
    │   │   ├── APIClientFactory.swift
    │   │   ├── APIError.swift          # problem+json → APIError(code, detail, fields)
    │   │   └── Middleware/
    │   │       ├── ClientInfoMiddleware.swift   # X-Device-ID, X-Platform, X-App-Version, X-Request-ID
    │   │       └── AuthMiddleware.swift         # Bearer + refresh single-flight
    │   ├── Auth/
    │   │   ├── KeychainStore.swift
    │   │   ├── TokenStore.swift
    │   │   ├── SessionStore.swift      # @Observable: signedOut, signedIn, needsLogin
    │   │   ├── AppleSignInCoordinator.swift
    │   │   └── GoogleSignInCoordinator.swift
    │   ├── Sync/
    │   │   ├── SyncEngine.swift        # actor, siklus SYNC_PROTOCOL.md §7
    │   │   ├── OutboxWriter.swift      # tulis entitas + outbox dalam satu transaksi GRDB
    │   │   ├── PushApplier.swift
    │   │   ├── PullApplier.swift
    │   │   ├── EntityCodec.swift       # record ↔ JSON snake_case
    │   │   ├── SyncScheduler.swift     # debounce, foreground, NWPathMonitor, BGAppRefreshTask
    │   │   └── SyncStatus.swift
    │   ├── DomainRules/                # port 1:1 dari BUSINESS_RULES.md, murni Swift
    │   │   ├── Rounding.swift
    │   │   ├── Period.swift
    │   │   ├── DomainTypes.swift       # struct nilai murni (Account, Transaction, BalanceSnapshot, BudgetGoal, YearMonth), tanpa GRDB
    │   │   ├── Balance.swift
    │   │   ├── Reconciliation.swift
    │   │   ├── Budget.swift
    │   │   └── Recurrence.swift
    │   ├── Billing/
    │   │   ├── BillingService.swift
    │   │   └── EntitlementStore.swift
    │   ├── Notifications/
    │   │   ├── NotificationService.swift
    │   │   └── NotificationScheduler.swift
    │   ├── Security/
    │   │   └── AppLockController.swift
    │   ├── Support/
    │   │   ├── IDGenerator.swift       # UUIDv7 (implementasi sendiri) + UUIDv5 (Insecure.SHA1 CryptoKit)
    │   │   ├── CivilDate.swift         # tanggal kalender, Codable "YYYY-MM-DD"
    │   │   ├── UserClock.swift         # "hari ini" di timezone user
    │   │   └── MoneyFormatter.swift    # Int64 → "Rp 25.000"
    │   └── DesignSystem/
    │       ├── AppColors.swift
    │       ├── CategoryIcons.swift     # key icon → SF Symbol
    │       ├── ProviderLogos.swift
    │       └── Components/             # AmountText, EmptyStateView, SyncBadge, NumpadView, dll.
    ├── Features/
    │   ├── Auth/
    │   ├── Onboarding/
    │   ├── Dashboard/
    │   ├── Transactions/
    │   ├── Accounts/
    │   ├── Reconciliation/
    │   ├── Budget/
    │   ├── Categories/
    │   ├── Reports/
    │   ├── Recurring/
    │   ├── Subscription/
    │   └── Settings/
    └── Resources/
        ├── Assets.xcassets             # warna, logo provider
        ├── Localizable.xcstrings       # bahasa Indonesia
        ├── Info.plist
        └── MoneyTracker.entitlements   # Sign in with Apple, background fetch
```

Isi setiap folder fitur:

```
Features/<Fitur>/
├── Data/          # <Fitur>Repository.swift: baca via ValueObservation, tulis via OutboxWriter
├── Models/        # model UI, satu per file
├── ViewModels/    # @Observable @MainActor
└── Views/
```

## 3. Aturan arsitektur

1. **View → ViewModel → Repository → database lokal.** View tidak mengakses GRDB, API, atau RevenueCat langsung.
2. Data domain dibaca lewat `ValueObservation` (diekspos sebagai `AsyncStream` dari repository), sehingga UI ter-update setelah tulis lokal maupun pull.
3. Semua tulis lewat `OutboxWriter`, lalu `SyncScheduler.requestSync()`.
4. Rumus hanya dari `Core/DomainRules`.
5. Semua query memfilter `deleted_at IS NULL`.
6. Uang `Int64`, tanggal transaksi `CivilDate`. Dilarang `Double`/`Decimal` untuk nominal.
7. Migration database lokal hanya di `DatabaseMigrations.swift` (`DatabaseMigrator`, satu `registerMigration` per versi).
8. Dependency diinjeksi dari `AppContainer` lewat `@Environment`, bukan singleton global.
9. Teks UI dari `Localizable.xcstrings`.

## 4. Detail teknis

### 4.1 Database

- File di Application Support dengan `FileProtectionType.completeUntilFirstUserAuthentication` (dienkripsi iOS Data Protection, tetap bisa diakses background task setelah device pertama kali dibuka).
- Tidak memakai SQLCipher di iOS.
- Logout: tutup pool, hapus file database, hapus item Keychain.

### 4.2 Auth

- Token di Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- `AuthMiddleware`: `401 token_expired` → refresh sekali (single-flight lewat actor) → ulangi request. `refresh_invalid`/`refresh_reused` → `SessionStore.needsLogin` tanpa menghapus database.
- Login iOS: **Sign in with Apple**, Google, dan email + password. Nama dari Apple hanya ada di login pertama, kirim ke server saat itu juga.

### 4.3 Sync

Implementasi persis `SYNC_PROTOCOL.md`. Khusus iOS:

- `SyncEngine` adalah `actor` (single-flight alami).
- `BGAppRefreshTask` identifier `<bundle id>.sync`, dijadwalkan ulang setiap selesai dan saat app ke background. Daftarkan di `Info.plist` (`BGTaskSchedulerPermittedIdentifiers`).
- Pemicu foreground: `scenePhase == .active`, `NWPathMonitor`, debounce 2 detik setelah tulis.

### 4.4 Billing

- `Purchases.configure(withAPIKey:)` saat start, `Purchases.shared.logIn(userId)` setelah login, `logOut()` saat logout.
- Paywall buatan sendiri dari `Offerings.current`. Tombol "Pulihkan Pembelian", tautan Syarat & Kebijakan Privasi wajib ada.
- Setelah pembelian: `GET /v1/me/entitlements` → simpan → buka fitur. Logika fitur memakai entitlement dari server.
- "Kelola langganan" membuka `AppStore.showManageSubscriptions(in:)`.

### 4.5 Notifikasi

Sama dengan Android (`FRONTEND_FLUTTER.md` §4.5), memakai `UNCalendarNotificationTrigger`. Jumlah notifikasi terjadwal dijaga di bawah batas 64 iOS.

### 4.6 UI

- Gaya native iOS: `List` dengan `insetGrouped`, SF Symbols, mode terang dan gelap, Dynamic Type.
- Warna nominal dan `hide_amounts` sama dengan Android.
- Form transaksi berupa sheet dengan numpad besar.

## 5. Navigasi dan layar

Tab: **Beranda · Transaksi · Akun · Budget · Lainnya**. Daftar layar dan fasenya sama dengan tabel di `FRONTEND_FLUTTER.md` §5, dengan perbedaan:

| Layar | Perbedaan iOS |
| --- | --- |
| Login / daftar | Tambah tombol Sign in with Apple (paling atas) |
| Form transaksi | Ditampilkan sebagai `.sheet` |
| Kelola langganan | `showManageSubscriptions` |

## 6. Build & konfigurasi

- `xcodegen generate` setiap kali `project.yml` berubah atau file ditambah.
- Nilai rahasia di `Config/Secrets.xcconfig` (tidak masuk repo), di-include oleh `Debug.xcconfig`/`Release.xcconfig`, lalu diteruskan ke `Info.plist` dan dibaca `AppConfig`.
- Bundle ID dan Team ID diisi user di `project.yml`.
- Capability: Sign in with Apple, Background Modes (Background fetch), In-App Purchase.
- `GOOGLE_IOS_REVERSED_CLIENT_ID` (`com.googleusercontent.apps.<angka>-<hash>`) didaftarkan sebagai URL scheme di `Info.plist` supaya Google Sign-In bisa kembali ke app; `GIDClientID` di `Info.plist` memakai `GOOGLE_IOS_CLIENT_ID`. ID token Google ber-`aud` iOS client ID, yang sudah termasuk di `GOOGLE_CLIENT_IDS` server.
- Build tanpa Simulator yang bisa dijalankan: `xcodebuild -scheme MoneyTracker -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation -skipMacroValidation CODE_SIGNING_ALLOWED=NO build` (plugin OpenAPI generator butuh `-skipPackagePluginValidation`).
- `API_BASE_URL` lokal untuk simulator: `http://localhost:8080` (origin saja; path API sudah diawali `/v1`) (tambahkan pengecualian ATS hanya di konfigurasi Debug).

## 6.1 SwiftUI Preview dan galeri layar (khusus Debug)

Layar bisa dilihat dan diubah di Canvas Xcode tanpa menjalankan app dan tanpa server.

- **Hanya DEBUG.** Semua kode preview dibungkus `#if DEBUG` dan tidak ikut build Release. Bukan file test.
- **Membuka Canvas:** buka file view atau `ContentView.swift`, lalu menu **Editor → Canvas** (⌥⌘↩). Pilih blok `#Preview` bernama di kiri bawah Canvas.
- **`ContentView.swift`** (di `MoneyTracker/`, sejajar `App/`) adalah galeri semua layar dengan pemilih varian. App sungguhan tetap mulai dari `RootView`; `ContentView` tidak dipakai di runtime.
- **`Core/Preview/`**: `PreviewSupport.swift` (`PreviewVariant`, `AppContainer.preview(_:)`, `PreviewHost`, `PreviewStack`) dan `PreviewSampleData.swift` (data contoh).
- **Container preview** memakai `DatabaseQueue` in-memory dengan migrasi yang sama, transport API yang selalu gagal, token store di memori (tanpa Keychain), status konektivitas tetap, dan tidak mendaftarkan BGTask. Tidak ada panggilan jaringan.
- **Data contoh varian "Berisi"** sama dengan `contracts/fixtures/business_rules/01_monthly_basic.json` (hari ini dipatok ke 2026-11-30), sehingga Dashboard menampilkan pemasukan 8.000.000, pengeluaran 1.852.500, dan surplus 6.147.500. Angka tetap dihitung `DomainRules` dari database contoh.
- **Varian:** Kosong, Berisi, Nominal disembunyikan, Menyinkronkan, Menunggu sync, Offline, Perlu login, Perlu perhatian, Mode gelap.
- Celah injeksi di kode produksi (semuanya `#if DEBUG`): `AppDatabase.init(writer:)`, `AppContainer.init(preview:...)`, `SessionStore.applyPreview`, `KeychainStore.memory`, `ConnectivityMonitor.init(previewOnline:)`, `UserClock.pinTodayForPreviews`. `AppDatabase.pool` bertipe `any DatabaseWriter`; jalur produksi tetap `DatabasePool` dan `wipeAndReopen` tetap bekerja.

## 7. Target perangkat & performa

- Deployment target iOS 18.0: berjalan di iPhone XS/XR (2018) ke atas.
- Daftar panjang memakai `List`/`LazyVStack` dengan paging dari GRDB, bukan memuat semua transaksi sekaligus.
- Observasi database hanya untuk data yang sedang tampil (misal bulan terpilih).
- Hindari efek visual berat berlapis (blur, shadow) di daftar.
- Grafik Swift Charts hanya dirender saat layar laporan dibuka.

## 8. Testing

Tidak ada file test dan tidak ada target test di `project.yml` (lihat `CLAUDE.md`). Verifikasi otomatis cukup build berhasil.
| `Sync/*` | Coalescing outbox, penerapan push, pull melewati baris yang masih di outbox (GRDB `DatabaseQueue()` in-memory) |

## 9. Catatan implementasi Fase 1 (keputusan dan perbedaan dari Flutter)

Perilaku sync, auth, dan aturan bisnis identik dengan Flutter. Yang berbeda hanya karena platform atau karena pilihan struktur Swift:

| Hal | Keputusan iOS |
| --- | --- |
| Jadwal background | `BGAppRefreshTask` tidak menjamin jadwal 30 menit. App hanya mengajukan `earliestBeginDate` = 30 menit; iOS yang memutuskan kapan (dan apakah) jalan, tergantung pemakaian app, baterai, mode hemat daya, dan pengaturan "Background App Refresh". Tidak berjalan di Simulator. Pemicu foreground (`scenePhase == .active`, `NWPathMonitor`, debounce 2 detik) tetap menjadi jalur utama. Task diajukan ulang saat app masuk background dan di awal setiap eksekusi task |
| Penanda `foreground_since` | Tetap diterapkan (heartbeat 60 detik, hapus saat background, task diam bila lebih baru dari 3 menit) walau task background iOS berjalan di proses yang sama dengan app, supaya perilaku identik dengan Android |
| Skema lokal | `batch_id` (outbox) dan `sync_error` (tiap tabel entitas) ditambahkan langsung ke migration `v1_init` (app belum dirilis). Instalasi dev yang lebih lama harus dihapus dulu |
| Klien API | Auth dan `/me` memakai klien hasil generator. Push dan pull memakai `RawAPI` (JSON mentah lewat `EntityCodec`) dengan rantai middleware yang sama: `ClientInfoMiddleware` → `UpgradeRequiredMiddleware` → `AuthMiddleware` → `ProblemMiddleware`. `ProblemMiddleware` melempar `APIError` untuk setiap respons non-2xx, jadi pemanggil hanya menangani kasus sukses. Klien refresh token tidak memakai `AuthMiddleware` |
| Logika murni sync | `Core/Sync/Logic/` hanya bergantung pada Foundation (coalescing, pemilihan batch, backoff, hasil push, aturan pull, kursor, perbaikan stale). Akses GRDB dan jaringan ada di file lain (`PushApplier`, `PullApplier`, `SyncEngine`, ...) |
| Keychain dan install ulang | Keychain bertahan setelah app dihapus, sedangkan database tidak. Saat peluncuran pertama setelah instal, item Keychain app dibersihkan supaya sesi lama tidak terbawa ke database kosong |
| Nonce OAuth | Field `nonce` dikirim berisi nilai yang dimasukkan ke permintaan penyedia: hash SHA-256 (hex) untuk Apple, nilai mentah untuk Google. Server masih mengabaikannya (lihat item hardening di `ROADMAP.md`) |
| Google Sign-In | URL kembali ditangani `.onOpenURL` di `MoneyTrackerApp`, bukan `AppDelegate` (app memakai siklus hidup scene SwiftUI). `AppDelegate` memiliki `AppContainer` supaya BGTask terdaftar sebelum app selesai diluncurkan, juga saat iOS meluncurkan app hanya untuk menjalankan task |
| Tanggal "hari ini" | Memakai timezone perangkat sampai Fase 2 (`UserClock`), sama seperti Flutter |
| Dashboard | Ringkasan bulan memakai `DomainRules.computeMonthlySummary` dengan transaksi bulan terpilih; `opening_total` belum ditampilkan sampai kartu Fase 2 |
| Verifikasi email | Ditampilkan sebagai sheet dari banner Beranda atau halaman Profil (di Flutter: route yang di-push) |
| Perlu login | `SyncBadge` "Perlu login" dan "Masuk" di initial sync membuka layar login sebagai sheet di atas app; app tetap dipakai di bawahnya |
| Setup wizard | "Tambah akun" membuka formulir akun sebagai sheet |
| Kategori | Urutkan lewat tombol Edit (drag); sembunyikan dan arsipkan lewat swipe |
| Teks UI | Kunci di `Localizable.xcstrings` adalah teks Indonesia itu sendiri (`sourceLanguage = id`); teks di luar View memakai `String(localized:)` |
| Tab Budget | Masih placeholder sampai Fase 2 |
