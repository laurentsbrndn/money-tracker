# Data Model

Dokumen ini mendefinisikan semua tabel di PostgreSQL (server). Skema database lokal di client mengikuti tabel bertanda **[sync]** dengan tambahan kolom lokal yang dijelaskan di `SYNC_PROTOCOL.md`.

## 1. Konvensi umum

| Hal | Aturan |
| --- | --- |
| Nama tabel/kolom | `snake_case`, tabel jamak |
| Primary key | `id uuid` |
| Uang | `bigint`, rupiah utuh. Contoh: Rp 25.000 → `25000` |
| Tanggal kalender | `date` (`YYYY-MM-DD`), tanpa jam dan zona waktu |
| Timestamp | `timestamptz`, selalu UTC |
| Enum | `varchar` + validasi di service (lihat tabel enum di bawah). Tidak memakai tipe `ENUM` PostgreSQL |
| Foreign key | Hanya **di dalam satu modul**. Referensi lintas modul (misal `transactions.account_id`) berupa kolom `uuid` biasa yang divalidasi service lewat API modul pemilik |
| Soft delete | Tabel [sync] memakai `deleted_at` (tombstone). Tabel lain tidak memakai soft delete kecuali disebut |

### 1.1 Kolom wajib tabel [sync]

Semua tabel bertanda **[sync]** memiliki kolom berikut (di Go: struct embedded `syncbase.Columns` di `platform/syncbase/columns.go`):

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `id` | uuid | tidak | PK. UUIDv7 dari client (atau ID deterministik, lihat `SYNC_PROTOCOL.md`) |
| `user_id` | uuid | tidak | Pemilik. Selalu diisi server dari token |
| `created_at` | timestamptz | tidak | Dari client |
| `updated_at` | timestamptz | tidak | Dari client, dasar last-write-wins |
| `deleted_at` | timestamptz | ya | Tombstone. Bukan `gorm.DeletedAt` (tombstone harus tetap ikut di pull) |
| `server_version` | bigint | tidak | `nextval('sync_version_seq')` setiap kali baris ditulis |
| `server_updated_at` | timestamptz | tidak | Waktu server saat baris terakhir ditulis |

Index wajib di setiap tabel [sync]: `(user_id, server_version)`.

### 1.2 Enum

| Enum | Nilai |
| --- | --- |
| `transaction_type` | `income`, `expense`, `transfer`, `adjustment` |
| `transaction_status` | `posted`, `pending_confirmation` |
| `allocation` | `needs`, `wants`, `savings` |
| `account_type` | `bank`, `e_wallet`, `cash`, `savings` |
| `category_type` | `expense`, `income` |
| `recurring_frequency` | `daily`, `weekly`, `monthly`, `yearly` |
| `recurring_mode` | `auto`, `confirm` |
| `user_status` | `active`, `pending_deletion` |
| `auth_provider` | `apple`, `google` |
| `token_purpose` | `email_verification`, `password_reset` |
| `store` | `app_store`, `play_store` |
| `subscription_status` | `active`, `in_grace_period`, `in_billing_retry`, `cancelled`, `expired`, `refunded` |
| `theme` | `system`, `light`, `dark` |

## 2. Modul identity

### `users`

| Kolom | Tipe | Null | Default | Keterangan |
| --- | --- | --- | --- | --- |
| `id` | uuid | tidak | – | UUIDv7 dari server |
| `email` | varchar(254) | ya | – | Selalu lowercase. Unique. Bisa null untuk login Apple yang tidak membagikan email |
| `email_verified_at` | timestamptz | ya | – | |
| `password_hash` | text | ya | – | argon2id. Null untuk user yang hanya login sosial |
| `name` | varchar(100) | tidak | – | |
| `status` | varchar(16) | tidak | `active` | `user_status` |
| `failed_login_count` | int | tidak | 0 | Reset saat login berhasil |
| `locked_until` | timestamptz | ya | – | Lockout setelah 10 kali gagal |
| `deletion_requested_at` | timestamptz | ya | – | Diisi saat hapus akun |
| `created_at` / `updated_at` | timestamptz | tidak | now() | |

Index: unique `email`.

### `auth_identities`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `id` | uuid | tidak | |
| `user_id` | uuid | tidak | FK `users.id` ON DELETE CASCADE |
| `provider` | varchar(16) | tidak | `auth_provider` |
| `provider_subject` | varchar(255) | tidak | Klaim `sub` dari ID token |
| `email` | varchar(254) | ya | Email dari provider saat pertama login |
| `created_at` | timestamptz | tidak | |

Index: unique `(provider, provider_subject)`, `(user_id)`.

### `refresh_tokens`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `id` | uuid | tidak | |
| `user_id` | uuid | tidak | FK `users.id` ON DELETE CASCADE |
| `family_id` | uuid | tidak | Sama untuk semua token hasil rotasi dari satu login |
| `token_hash` | char(64) | tidak | SHA-256 hex dari token. Unique |
| `device_id` | varchar(64) | tidak | ID instalasi app |
| `device_name` | varchar(100) | ya | Contoh "iPhone 15" |
| `ip_address` | varchar(45) | ya | IP klien saat sesi dibuat (dari header proxy). Hanya untuk audit sesi, tidak dipakai untuk keputusan keamanan. Ditambahkan oleh migration `202611030001_refresh_token_ip` |
| `expires_at` | timestamptz | tidak | Dibuat + 60 hari |
| `rotated_at` | timestamptz | ya | Diisi saat token ini ditukar dengan token baru |
| `revoked_at` | timestamptz | ya | Logout atau deteksi reuse |
| `created_at` | timestamptz | tidak | |

Index: unique `token_hash`, `(user_id)`, `(family_id)`.

### `verification_tokens`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `id` | uuid | tidak | |
| `user_id` | uuid | tidak | FK `users.id` ON DELETE CASCADE |
| `purpose` | varchar(32) | tidak | `token_purpose` |
| `code_hash` | char(64) | tidak | HMAC-SHA256 (kunci env `OTP_SECRET`) dari kode 6 digit + `user_id` |
| `attempts` | smallint | tidak | Default 0, maksimal 5 percobaan salah |
| `expires_at` | timestamptz | tidak | Dibuat + 15 menit |
| `used_at` | timestamptz | ya | |
| `created_at` | timestamptz | tidak | |

Index: `(user_id, purpose, created_at)`. Hanya kode terbaru per `(user_id, purpose)` yang berlaku; membuat kode baru menandai kode lama `used_at`.

### `user_settings` [sync]

`id` **sama dengan** `user_id` (satu baris per user).

| Kolom | Tipe | Null | Default | Keterangan |
| --- | --- | --- | --- | --- |
| `timezone` | varchar(64) | tidak | `Asia/Jakarta` | Nama IANA |
| `currency` | char(3) | tidak | `IDR` | |
| `week_start` | smallint | tidak | 1 | 1 = Senin, 7 = Minggu |
| `theme` | varchar(8) | tidak | `system` | `theme` |
| `daily_reminder_time` | varchar(5) | ya | – | `HH:MM` waktu lokal |
| `reconcile_reminder_enabled` | boolean | tidak | true | |
| `budget_alert_enabled` | boolean | tidak | true | |
| `hide_amounts` | boolean | tidak | false | |

## 3. Modul category

### `categories` [sync]

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `type` | varchar(8) | tidak | `category_type` |
| `name` | varchar(50) | tidak | Unik per user + type di antara yang belum dihapus (divalidasi service, case-insensitive) |
| `icon` | varchar(50) | tidak | Key ikon, sama di kedua app (contoh `food`, `transport`) |
| `color` | varchar(7) | tidak | `#RRGGBB` |
| `default_allocation` | varchar(8) | ya | Wajib untuk `expense`, null untuk `income` |
| `sort_order` | int | tidak | |
| `is_default` | boolean | tidak | true bila hasil seed |
| `is_hidden` | boolean | tidak | Disembunyikan dari form |
| `archived_at` | timestamptz | ya | Diarsipkan, transaksi lama tetap merujuk |

Index: `(user_id, type)`.

## 4. Modul wallet

### `accounts` [sync]

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `name` | varchar(50) | tidak | |
| `type` | varchar(16) | tidak | `account_type` |
| `provider_key` | varchar(32) | ya | Key logo dari daftar statis (contoh `bca`, `gopay`) |
| `currency` | char(3) | tidak | `IDR` |
| `opening_balance` | bigint | tidak | Boleh negatif |
| `opening_date` | date | tidak | Transaksi akun ini tidak boleh sebelum tanggal ini |
| `include_in_total` | boolean | tidak | Default true |
| `sort_order` | int | tidak | |
| `archived_at` | timestamptz | ya | |

### `balance_snapshots` [sync]

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `account_id` | uuid | tidak | FK `accounts.id` (satu modul) |
| `snapshot_date` | date | tidak | |
| `amount` | bigint | tidak | Saldo asli yang dilihat user |
| `note` | varchar(255) | ya | |

Tidak ada unique constraint pada `(account_id, snapshot_date)` karena dua device offline bisa membuat snapshot di hari yang sama. Snapshot "terbaru" = `snapshot_date` terbesar, lalu `updated_at` terbesar.

Index: `(user_id, account_id, snapshot_date)`.

## 5. Modul ledger

### `transactions` [sync]

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `type` | varchar(16) | tidak | `transaction_type` |
| `status` | varchar(24) | tidak | `transaction_status`, default `posted` |
| `transaction_date` | date | tidak | |
| `amount` | bigint | tidak | > 0 untuk `income`/`expense`/`transfer`. Untuk `adjustment` ≠ 0 dan bertanda (+ menambah saldo, − mengurangi) |
| `currency` | char(3) | tidak | `IDR` |
| `account_id` | uuid | tidak | Akun utama: tujuan income, sumber expense, asal transfer, akun adjustment |
| `to_account_id` | uuid | ya | Wajib hanya untuk `transfer` |
| `category_id` | uuid | ya | Wajib untuk `expense`, opsional untuk `income`, null untuk transfer/adjustment |
| `allocation` | varchar(8) | ya | Wajib hanya untuk `expense` |
| `source` | varchar(100) | ya | "Dari mana", hanya `income` |
| `note` | varchar(255) | ya | "Buat apa" / catatan bebas |
| `linked_transaction_id` | uuid | ya | Expense biaya admin → transfer induknya |
| `recurring_rule_id` | uuid | ya | Diisi bila dibuat dari aturan berulang |

Index: `(user_id, transaction_date)`, `(user_id, account_id, transaction_date)`, `(user_id, to_account_id)`, `(user_id, recurring_rule_id)`.

### `recurring_rules` [sync]

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `type` | varchar(16) | tidak | `income`, `expense`, atau `transfer` |
| `amount` | bigint | tidak | > 0 |
| `account_id` / `to_account_id` / `category_id` / `allocation` / `source` / `note` | – | – | Template, aturan sama dengan `transactions` |
| `frequency` | varchar(8) | tidak | `recurring_frequency` |
| `interval_count` | smallint | tidak | Default 1 (setiap 1 minggu, 2 minggu, dst.) |
| `day_of_week` | smallint | ya | 1–7, untuk `weekly` |
| `day_of_month` | smallint | ya | 1–31, untuk `monthly` dan `yearly` |
| `month_of_year` | smallint | ya | 1–12, untuk `yearly` |
| `start_date` | date | tidak | |
| `end_date` | date | ya | |
| `mode` | varchar(8) | tidak | `recurring_mode` |
| `is_paused` | boolean | tidak | Otomatis true saat premium berakhir |
| `last_generated_date` | date | ya | Tanggal kemunculan terakhir yang sudah dibuat |

## 6. Modul budget

### `budget_goals` [sync]

`id` deterministik: UUIDv5(`NAMESPACE_BUDGET_GOAL`, `"<user_id>|<YYYY-MM>"`). Lihat `SYNC_PROTOCOL.md`.

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `effective_month` | date | tidak | Selalu tanggal 1 |
| `needs_pct` | smallint | tidak | 0–100 |
| `wants_pct` | smallint | tidak | 0–100 |
| `savings_pct` | smallint | tidak | 0–100, total ketiganya = 100 |
| `planned_income` | bigint | ya | Rencana income bulanan |

Goal yang berlaku untuk bulan M = baris dengan `effective_month` terbesar yang ≤ M dan belum dihapus.

Index: `(user_id, effective_month)`.

## 7. Modul sync

### `sync_idempotency_keys`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `user_id` | uuid | tidak | PK bagian 1 |
| `idempotency_key` | varchar(64) | tidak | PK bagian 2 |
| `response` | jsonb | tidak | Respons push yang disimpan |
| `created_at` | timestamptz | tidak | Dibersihkan cron setelah 24 jam |

### Sequence `sync_version_seq`

`bigint`, mulai 1, dipakai semua tabel [sync].

## 8. Modul billing

### `subscriptions`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `id` | uuid | tidak | |
| `user_id` | uuid | tidak | |
| `store` | varchar(16) | tidak | `store` |
| `product_id` | varchar(100) | tidak | Contoh `premium_monthly` |
| `status` | varchar(24) | tidak | `subscription_status` |
| `period_type` | varchar(16) | tidak | `trial`, `intro`, `normal` |
| `current_period_start` | timestamptz | tidak | |
| `current_period_end` | timestamptz | tidak | |
| `will_renew` | boolean | tidak | |
| `original_transaction_id` | varchar(100) | tidak | |
| `environment` | varchar(12) | tidak | `sandbox` / `production` |
| `created_at` / `updated_at` | timestamptz | tidak | |

Index: unique `(store, original_transaction_id)`, `(user_id)`.

### `entitlements`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `user_id` | uuid | tidak | PK bagian 1 |
| `entitlement_key` | varchar(32) | tidak | PK bagian 2, saat ini hanya `premium` |
| `is_active` | boolean | tidak | |
| `expires_at` | timestamptz | ya | |
| `subscription_id` | uuid | ya | FK `subscriptions.id` |
| `updated_at` | timestamptz | tidak | |

### `billing_events`

| Kolom | Tipe | Null | Keterangan |
| --- | --- | --- | --- |
| `id` | varchar(100) | tidak | PK = event ID RevenueCat (idempotensi) |
| `user_id` | uuid | ya | Dari `app_user_id` |
| `type` | varchar(50) | tidak | Contoh `INITIAL_PURCHASE`, `RENEWAL`, `EXPIRATION` |
| `event_timestamp` | timestamptz | tidak | |
| `payload` | jsonb | tidak | Body webhook asli |
| `received_at` | timestamptz | tidak | |
| `processed_at` | timestamptz | ya | |
| `error` | text | ya | Pesan error bila gagal diproses |

## 9. Data seed per user baru

Dibuat dalam satu transaksi database saat register (lihat `BUSINESS_RULES.md` §2 untuk daftar kategori):

1. `user_settings` dengan `id = user_id`, timezone dari request register.
2. Kategori default (expense + income).
3. Akun `Cash` (`type = cash`, `opening_balance = 0`, `opening_date` = hari ini di timezone user).
4. `budget_goals` 50/30/20 untuk bulan berjalan.

Semua baris seed mendapat `server_version` sehingga ikut terkirim di initial pull.

Rincian seed:

- `user_settings`: `timezone` dari request register, `currency = IDR`, `week_start = 1`, `theme = system`, `daily_reminder_time` null, pengingat rekonsiliasi dan peringatan budget aktif, `hide_amounts = false`.
- Kategori: `is_default = true`, `is_hidden = false`, `sort_order` = urutan di dalam tipenya (tabel `BUSINESS_RULES.md` §2.1), warna di bawah. Kedua client membaca warna dari baris yang disinkron, jadi nilai ini adalah satu-satunya sumber.
- Akun `Cash`: `sort_order = 0`, `opening_date` = hari ini di timezone request, plus satu `balance_snapshots` (`snapshot_date = opening_date`, `amount = 0`).
- `budget_goals`: 50/30/20, `effective_month` = tanggal 1 bulan berjalan di timezone request, `planned_income` null, id UUIDv5.

Palet warna kategori default:

| Ikon | Warna | Ikon | Warna |
| --- | --- | --- | --- |
| `food` | `#F59E0B` | `investment` | `#14B8A6` |
| `transport` | `#3B82F6` | `other` | `#9CA3AF` |
| `home` | `#8B5CF6` | `salary` | `#22C55E` |
| `bill` | `#EF4444` | `freelance` | `#0EA5E9` |
| `health` | `#10B981` | `bonus` | `#84CC16` |
| `education` | `#06B6D4` | `gift` | `#D946EF` (expense dan income) |
| `fee` | `#6B7280` | `shopping` | `#EC4899` |
| `entertainment` | `#F97316` | `subscription` | `#6366F1` |
| `snack` | `#EAB308` | | |
