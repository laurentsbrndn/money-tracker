# Sync Protocol (Offline-First)

Dokumen ini wajib diikuti persis oleh backend, Flutter, dan iOS. Perubahan protokol harus disetujui user dan dicatat di sini lebih dulu.

## 1. Prinsip

1. Database lokal adalah sumber data UI. UI tidak pernah menunggu server untuk menampilkan atau menyimpan data domain.
2. Setiap perubahan lokal ditulis ke tabel entitas **dan** ke `outbox` dalam satu transaksi database lokal.
3. Sync = **push** (kirim outbox) lalu **pull** (ambil perubahan sejak cursor).
4. Konflik diselesaikan **last-write-wins per baris** berdasarkan `updated_at` dari client.
5. Data tidak pernah dihapus permanen lewat sync; penghapusan = tombstone (`deleted_at`).
6. Setiap operasi idempoten: mengirim ulang push yang sama tidak boleh menghasilkan data ganda.

## 2. Entitas yang disinkron

| Nama entitas (`entity`) | Tabel server | Modul pemilik | Arah |
| --- | --- | --- | --- |
| `user_settings` | `user_settings` | identity | push + pull |
| `categories` | `categories` | category | push + pull |
| `accounts` | `accounts` | wallet | push + pull |
| `balance_snapshots` | `balance_snapshots` | wallet | push + pull |
| `transactions` | `transactions` | ledger | push + pull |
| `recurring_rules` | `recurring_rules` | ledger | push + pull |
| `budget_goals` | `budget_goals` | budget | push + pull |

Status premium tidak disinkron sebagai entitas. Ia dikirim sebagai `meta.entitlement` di setiap respons pull (read-only).

Urutan prioritas push (dipakai bila client mengurutkan ulang): `user_settings`, `accounts`, `categories`, `budget_goals`, `recurring_rules`, `transactions`, `balance_snapshots`. Dalam praktik, urutan waktu outbox sudah menjamin parent dibuat sebelum child.

## 3. ID

| Entitas | Cara membuat ID |
| --- | --- |
| Umum | UUIDv7 dibuat client saat record dibuat |
| `user_settings` | `id = user_id` |
| `budget_goals` | UUIDv5(`NS_BUDGET_GOAL`, `"<user_id>\|<YYYY-MM>"`) |
| Kemunculan transaksi berulang | UUIDv5(`NS_RECURRING_OCCURRENCE`, `"<recurring_rule_id>\|<YYYY-MM-DD>"`) |

Konstanta namespace (identik di ketiga platform):

```
NS_BUDGET_GOAL           = 2c985cd5-0cd0-404d-bcea-4cca9c3f7437
NS_RECURRING_OCCURRENCE  = 151a0b48-a293-4aba-95a8-6562233ef7af
```

Semua UUID dikirim sebagai string lowercase dengan tanda hubung. String input UUIDv5 memakai UUID lowercase.

ID deterministik membuat dua device (atau device dan server) yang membuat record "yang sama" menghasilkan ID yang sama, sehingga hanya satu baris yang tersimpan.

## 4. Format data

- Payload memakai nama kolom `snake_case` persis seperti `DATA_MODEL.md`.
- Kolom yang **tidak** dikirim client: `user_id`, `server_version`, `server_updated_at` (diisi server, diabaikan bila dikirim).
- Tanggal kalender: `"2026-11-02"`.
- Timestamp: RFC 3339 UTC dengan milidetik, `"2026-11-02T14:05:00.123Z"`.
- Uang: integer JSON (`25000`), bukan string, bukan desimal.
- Upsert selalu mengirim **seluruh baris** (bukan patch).

## 5. Skema lokal client

### 5.1 Tabel entitas

Mirror dari tabel [sync] server (tanpa `user_id`), ditambah:

| Kolom | Tipe | Keterangan |
| --- | --- | --- |
| `server_version` | integer, nullable | Null bila belum pernah diterima server |
| `sync_status` | text | `synced`, `pending`, `failed` |

### 5.2 `outbox`

| Kolom | Tipe | Keterangan |
| --- | --- | --- |
| `seq` | integer autoincrement | Urutan kirim |
| `entity` | text | Nama entitas (§2) |
| `record_id` | text | UUID |
| `op` | text | `upsert` atau `delete` |
| `payload` | text (JSON) | Seluruh baris untuk `upsert`; kosong untuk `delete` |
| `updated_at` | text | `updated_at` record saat dimasukkan |
| `attempts` | integer | Jumlah percobaan gagal yang retryable |
| `next_attempt_at` | text, nullable | Untuk backoff |
| `last_error` | text, nullable | Kode + pesan error terakhir |
| `created_at` | text | |

### 5.3 `sync_state` (key-value)

| Key | Isi |
| --- | --- |
| `device_id` | UUID instalasi, dibuat sekali |
| `pull_cursor` | `server_version` terakhir yang sudah diterapkan, default `0` |
| `last_sync_at` | Timestamp sync sukses terakhir |
| `entitlement` | JSON `meta.entitlement` terakhir |

## 6. Menulis data di client

Dalam **satu transaksi lokal**:

1. Set `updated_at = now()` (UTC). Untuk record baru, `created_at = updated_at`.
2. Tulis baris dengan `sync_status = pending`.
3. Masukkan ke outbox dengan aturan coalescing:
    1. Bila sudah ada entri outbox untuk `(entity, record_id)` yang **belum sedang dikirim**, timpa `op`, `payload`, dan `updated_at`-nya (tidak menambah entri baru).
    2. Delete pada record yang belum pernah diterima server (`server_version` null): hapus entri outbox-nya dan hapus barisnya secara permanen di lokal. Tidak ada yang dikirim.
    3. Selain itu, tambahkan entri baru.
4. Setelah commit, jadwalkan sync (debounce 2 detik).

Soft delete lokal: isi `deleted_at`, dan semua query UI wajib memfilter `deleted_at IS NULL`.

## 7. Siklus sync (client)

```
sync():
  if sedang sync → tandai "perlu sync lagi" lalu return (single-flight)
  if offline → return
  pastikan access token valid (refresh bila perlu; gagal refresh → status needs_login, return)
  loop push:
     ambil ≤ 100 entri outbox yang next_attempt_at ≤ now, urut seq
     if kosong → break
     kirim POST /v1/sync/push
     terapkan hasil per entri (§8.4)
     if ada error jaringan/5xx → backoff, return
  loop pull:
     GET /v1/sync/pull?since=<pull_cursor>&limit=500
     terapkan perubahan (§9.3) + simpan cursor baru dalam satu transaksi lokal
     simpan meta.entitlement
     if !has_more → break
  last_sync_at = now
  if "perlu sync lagi" → ulangi sekali
```

### Pemicu

- 2 detik setelah perubahan lokal terakhir.
- App kembali ke foreground.
- Koneksi kembali (Android `connectivity_plus`, iOS `NWPathMonitor`).
- Pull-to-refresh di Dashboard dan daftar transaksi.
- Background: WorkManager (Android, periodik 30 menit, butuh jaringan) dan `BGAppRefreshTask` (iOS, dijadwalkan sistem).

### Backoff

Error retryable: tunda entri / siklus dengan jeda 5 s, 15 s, 1 m, 5 m, lalu maksimal 15 m. Reset setelah sukses.

## 8. Push

### 8.1 Request

`POST /v1/sync/push`

Header: `Authorization: Bearer <access>`, `Idempotency-Key: <uuid batch>`, `X-Device-ID: <device_id>`.

```json
{
  "changes": [
    {
      "entity": "transactions",
      "op": "upsert",
      "id": "0193f0a2-7c1e-7b3a-9d2e-1f4a5b6c7d8e",
      "updated_at": "2026-11-02T14:05:00.123Z",
      "data": {
        "id": "0193f0a2-7c1e-7b3a-9d2e-1f4a5b6c7d8e",
        "type": "expense",
        "status": "posted",
        "transaction_date": "2026-11-02",
        "amount": 25000,
        "currency": "IDR",
        "account_id": "0193f09f-1111-7aaa-8bbb-222233334444",
        "to_account_id": null,
        "category_id": "0193f09f-5555-7ccc-8ddd-666677778888",
        "allocation": "needs",
        "source": null,
        "note": "makan siang",
        "linked_transaction_id": null,
        "recurring_rule_id": null,
        "created_at": "2026-11-02T14:05:00.123Z",
        "updated_at": "2026-11-02T14:05:00.123Z",
        "deleted_at": null
      }
    },
    {
      "entity": "transactions",
      "op": "delete",
      "id": "0193f0a0-aaaa-7bbb-8ccc-dddd00001111",
      "updated_at": "2026-11-02T14:06:10.000Z"
    }
  ]
}
```

Batas: maksimal 100 entri per request, body maksimal 1 MB.

Aturan `null` pada `data`: `data` adalah seluruh baris. Untuk field nullable, key yang tidak ada diperlakukan sama dengan `null`. Field wajib non-null harus ada, bila tidak entri ditolak dengan `validation`. Client boleh mengirim `null` eksplisit atau menghilangkan key; hasilnya sama.

### 8.2 Algoritma server

1. Bila `(user_id, Idempotency-Key)` sudah ada di `sync_idempotency_keys` → kembalikan respons yang tersimpan, selesai.
2. Mulai satu transaksi database dan ambil **advisory lock per user** (`pg_advisory_xact_lock`) — lihat §10.
3. Untuk setiap entri, berurutan, dalam **savepoint** masing-masing (`tx.SavePoint` / `tx.RollbackTo` GORM):
    1. Cari `SyncHandler` untuk `entity` di registry. Tidak ada → `rejected` `unknown_entity`.
    2. Clamp: bila `updated_at` > waktu server + 5 menit, pakai waktu server.
    3. Ambil baris yang ada berdasarkan `id` **tanpa** filter user. Bila ada dan milik user lain → `rejected` `forbidden`.
    4. Bila baris ada dan `updated_at` kiriman ≤ `updated_at` tersimpan → `stale` (tidak ditulis).
    5. `op = delete`: bila baris tidak ada → `applied` (no-op). Bila ada → set `deleted_at = updated_at kiriman`, `updated_at` = kiriman.
    6. `op = upsert`: handler modul memvalidasi data (aturan di `BUSINESS_RULES.md` §6, kepemilikan referensi, batas plan) lalu insert atau update seluruh baris.
    7. Setiap tulis mengisi `server_version = nextval('sync_version_seq')` dan `server_updated_at = now()`.
    8. Error validasi → rollback ke savepoint, status `rejected`.
4. Simpan respons ke `sync_idempotency_keys`, commit.

### 8.3 Response `200 OK`

```json
{
  "results": [
    { "entity": "transactions", "id": "0193f0a2-…", "status": "applied", "server_version": 1042 },
    { "entity": "transactions", "id": "0193f0a0-…", "status": "stale", "server_version": 1037 },
    {
      "entity": "accounts", "id": "0193f0a3-…", "status": "rejected",
      "error": { "code": "plan_limit", "message": "Batas akun paket gratis tercapai", "retryable": false }
    }
  ],
  "server_time": "2026-11-02T14:06:11.500Z"
}
```

`server_version` pada hasil `applied` bersifat nullable: `null` untuk `delete` no-op (baris memang tidak ada di server). Client tidak boleh menganggap `server_version` selalu terisi.

Kode `rejected`:

| `code` | Arti | `retryable` |
| --- | --- | --- |
| `validation` | Data melanggar aturan (detail di `message` + `fields`) | false |
| `reference_missing` | Akun/kategori/rule yang dirujuk belum ada di server | true |
| `forbidden` | ID milik user lain | false |
| `plan_limit` | Melewati batas paket gratis | false |
| `unknown_entity` | Nama entitas tidak dikenal | false |

Error di level request (bukan per entri) memakai format problem+json (`API.md`): 401 (token), 413 (terlalu besar), 422 (body tidak valid), 5xx.

### 8.4 Menerapkan hasil push di client

| Status | Tindakan |
| --- | --- |
| `applied` | Hapus entri outbox. Bila baris lokal tidak berubah sejak dikirim (`updated_at` sama), set `server_version` dan `sync_status = synced` |
| `stale` | Hapus entri outbox. Baris tetap `pending` sampai pull menimpanya dengan versi server |
| `rejected` + `retryable` | `attempts += 1`, set `next_attempt_at` (backoff). Setelah 10 kali → perlakukan sebagai non-retryable |
| `rejected` non-retryable | Hapus dari outbox, set `sync_status = failed`, simpan `last_error`. Tampil di "Perlu perhatian"; user bisa memperbaiki (membuat upsert baru) atau membuang perubahan (ambil ulang versi server lewat pull penuh entitas itu) |

## 9. Pull

### 9.1 Request

`GET /v1/sync/pull?since=<cursor>&limit=<n>` — `limit` default 500, maksimal 1000.

### 9.2 Algoritma server

1. Untuk setiap tabel [sync]: ambil baris `user_id = me AND server_version > since ORDER BY server_version LIMIT n`.
2. Gabungkan semua hasil, urutkan berdasarkan `server_version`, potong menjadi `n` baris pertama.
3. `next_cursor` = `server_version` baris terakhir yang dikembalikan (atau `since` bila kosong).
4. `has_more` = true bila ada baris lain dengan `server_version > next_cursor` di salah satu tabel.
5. Sertakan `meta.entitlement` dari modul billing.

### 9.3 Response `200 OK`

```json
{
  "changes": [
    {
      "entity": "accounts",
      "id": "0193f09f-1111-7aaa-8bbb-222233334444",
      "server_version": 1001,
      "data": { "id": "0193f09f-…", "name": "Cash", "type": "cash", "…": "…", "deleted_at": null }
    }
  ],
  "next_cursor": 1042,
  "has_more": false,
  "meta": {
    "entitlement": { "premium": true, "expires_at": "2026-12-02T14:00:00Z", "will_renew": true },
    "server_time": "2026-11-02T14:06:12.000Z"
  }
}
```

`data` berisi seluruh baris termasuk tombstone (`deleted_at` terisi), **tanpa** `user_id`, `server_version`, dan `server_updated_at`. `server_version` hanya ada di envelope perubahan (`changes[].server_version`).

### 9.4 Menerapkan pull di client

Dalam satu transaksi lokal per halaman:

1. Untuk setiap perubahan:
    1. Bila masih ada entri outbox untuk `(entity, id)` itu → **lewati** (perubahan lokal menunggu push dan akan diputuskan LWW di server). Yang menentukan adalah keberadaan entri outbox, bukan nilai `sync_status`.
    2. Selain itu → upsert seluruh baris, set `server_version`, `sync_status = synced`.
2. Simpan `pull_cursor = next_cursor`.

## 10. Konsistensi cursor (wajib di server)

Masalah: `server_version` diambil dari sequence saat transaksi berjalan. Bila dua transaksi untuk user yang sama berjalan bersamaan, transaksi dengan versi lebih kecil bisa commit **setelah** versi lebih besar, dan client yang pull di antaranya akan melompati baris itu selamanya.

Aturan pencegahan: **setiap penulisan ke tabel [sync] milik seorang user wajib berada dalam transaksi yang memegang `pg_advisory_xact_lock(<hash user_id>)`**. Ini berlaku untuk:

- `POST /v1/sync/push`
- Seed data saat register
- Cron pembuatan transaksi berulang
- Pause `recurring_rules` saat premium berakhir (webhook billing)
- Penghapusan akun user

Lock disediakan oleh `platform/database.LockUser(ctx, tx, userID)`. Lock level transaksi aman dipakai dengan PgBouncer mode transaction (Neon pooled).

## 11. Auth dan sync

- Token kedaluwarsa saat offline tidak menghalangi pemakaian app.
- Sebelum sync, client me-refresh token bila access token habis atau tersisa < 60 detik.
- Refresh gagal permanen (401 dari `/v1/auth/refresh`) → status `needs_login`. Data lokal dan outbox **tidak dihapus**.
- Login ulang sebagai user yang sama → sync lanjut. Login sebagai user berbeda → wajib logout penuh dulu (hapus database lokal), dengan peringatan bila outbox tidak kosong.

## 12. Initial sync dan device baru

1. Setelah login/register: `pull_cursor = 0`, pull sampai `has_more = false`.
2. Selama initial pull, tampilkan layar "Menyiapkan data…" dengan progres jumlah baris.
3. Initial pull boleh terputus; karena cursor disimpan per halaman, pull dilanjutkan dari halaman terakhir.

## 13. Skenario uji manual

Dipakai user untuk menguji sendiri. Claude Code tidak membuat file test untuk skenario ini.

| # | Skenario | Hasil yang diharapkan |
| --- | --- | --- |
| S1 | Buat transaksi offline, lalu online | Transaksi muncul di server, lokal `synced` |
| S2 | Push yang sama dikirim dua kali (Idempotency-Key sama) | Respons identik, tidak ada baris ganda |
| S3 | Device A dan B mengedit transaksi sama offline, B lebih baru | Setelah keduanya sync, kedua device berisi versi B |
| S4 | Buat lalu hapus record sebelum pernah sync | Tidak ada yang dikirim ke server |
| S5 | Hapus di device A, edit di device B dengan `updated_at` lebih lama | Tetap terhapus |
| S6 | Edit di device B dengan `updated_at` lebih baru dari delete A | Baris hidup lagi dengan data B |
| S7 | Transaksi merujuk akun yang belum di-push | `reference_missing`, sukses di percobaan berikutnya |
| S8 | User free membuat akun ke-5 offline | `plan_limit`, akun `failed` di lokal |
| S9 | Pull terputus di tengah | Lanjut dari cursor terakhir tanpa kehilangan baris |
| S10 | Dua push paralel untuk user yang sama | Tidak ada baris yang terlewat oleh pull (advisory lock) |
| S11 | `updated_at` client 1 jam di masa depan | Dipotong ke waktu server |
| S12 | Kemunculan berulang dibuat app dan cron bersamaan | Satu baris (ID deterministik) |
