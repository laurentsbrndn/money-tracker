# API

`contracts/openapi.yaml` adalah sumber kebenaran. Dokumen ini adalah ringkasan yang dipakai untuk menulis spec OpenAPI di Fase 0; bila keduanya berbeda, perbarui keduanya setelah disetujui user.

## 1. Konvensi

| Hal | Aturan |
| --- | --- |
| Base URL | Origin `https://<project>.vercel.app` (production), `http://localhost:8080` (lokal). Semua path di dokumen ini dan di OpenAPI sudah diawali `/v1` (kecuali `/healthz`), jadi `API_BASE_URL` di client berisi origin saja |
| Format | JSON UTF-8, field `snake_case` |
| Auth | `Authorization: Bearer <access_token>` kecuali endpoint bertanda **publik** |
| Waktu | Timestamp RFC 3339 UTC; tanggal `YYYY-MM-DD`; bulan `YYYY-MM` |
| Uang | Integer rupiah |
| Request ID | Server selalu mengembalikan `X-Request-ID` (memakai nilai dari client bila dikirim) |
| Identitas client | Header `X-Device-ID`, `X-Platform` (`android`/`ios`), `X-App-Version` (semver) wajib di semua request dari app |

Header identitas client yang hilang atau tidak valid (`X-Device-ID` kosong, `X-Platform` selain `android`/`ios`, `X-App-Version` bukan semver) dijawab `422` dengan `code = validation` dan `fields` berisi nama header yang salah. Pembandingan semver diimplementasikan sendiri di backend (tanpa library tambahan).

### 1.1 Versi minimum app

Bila `X-App-Version` < `MIN_APP_VERSION_ANDROID` / `MIN_APP_VERSION_IOS` (env), server membalas `426` dengan `code = upgrade_required`. App menampilkan layar "Perbarui aplikasi".

### 1.2 Format error (RFC 9457, `application/problem+json`)

```json
{
  "type": "https://moneytracker.app/errors/validation",
  "title": "Validation failed",
  "status": 422,
  "detail": "Beberapa field tidak valid",
  "code": "validation",
  "fields": [{ "field": "email", "message": "format email tidak valid" }],
  "request_id": "01JC0Z…"
}
```

`code` stabil dan dipakai app untuk logika; `detail` boleh berubah.

| `code` | HTTP | Keterangan |
| --- | --- | --- |
| `validation` | 422 | Body/query tidak valid |
| `unauthorized` | 401 | Token tidak ada atau tidak valid |
| `token_expired` | 401 | Access token kedaluwarsa → refresh |
| `refresh_invalid` | 401 | Refresh token tidak valid/kedaluwarsa → login ulang |
| `refresh_reused` | 401 | Refresh token lama dipakai lagi → seluruh family dicabut, login ulang |
| `invalid_credentials` | 401 | Email/password salah |
| `account_locked` | 423 | Terlalu banyak gagal login; `retry_after_seconds` disertakan |
| `email_taken` | 409 | Email sudah terdaftar |
| `code_invalid` | 422 | Kode verifikasi/reset salah |
| `code_expired` | 422 | Kode kedaluwarsa |
| `too_many_attempts` | 429 | Kode salah 5 kali, minta kode baru |
| `forbidden` | 403 | Bukan milik user |
| `not_found` | 404 | |
| `premium_required` | 403 | Fitur premium |
| `history_limit` | 403 | Bulan di luar batas riwayat paket gratis |
| `payload_too_large` | 413 | |
| `rate_limited` | 429 | |
| `upgrade_required` | 426 | Versi app terlalu lama |
| `internal` | 500 | |

## 2. Auth (`identity`)

Respons token (dipakai semua endpoint login/register/refresh):

```json
{
  "user": { "id": "…", "name": "Brandon", "email": "a@b.com", "email_verified": false, "has_password": true, "providers": ["google"] },
  "tokens": {
    "access_token": "eyJ…",
    "access_expires_at": "2026-11-02T14:20:00Z",
    "refresh_token": "b64url…",
    "refresh_expires_at": "2027-01-01T14:05:00Z"
  },
  "is_new_user": true
}
```

| Method & path | Publik | Body | Sukses |
| --- | --- | --- | --- |
| `POST /auth/register` | ya | `name`, `email`, `password` (8–72 karakter), `timezone` | 201 + respons token; kode verifikasi dikirim ke email |
| `POST /auth/login` | ya | `email`, `password` | 200 + respons token |
| `POST /auth/oauth/apple` | ya | `identity_token`, `name` (opsional, hanya ada saat login pertama), `timezone` | 200 + respons token (`is_new_user` true bila baru) |
| `POST /auth/oauth/google` | ya | `id_token`, `timezone` | 200 + respons token |
| `POST /auth/refresh` | ya | `refresh_token` | 200 + `tokens` baru (token lama di-rotate) |
| `POST /auth/logout` | ya | `refresh_token` | 204, token dicabut. Autentikasi lewat refresh token di body, bukan Bearer, karena access token bisa sudah kedaluwarsa. Token tidak dikenal tetap dijawab 204 |
| `POST /auth/email/verification` | tidak | – | 202, kirim ulang kode (maks 1 per 60 detik) |
| `POST /auth/email/verify` | tidak | `code` (6 digit) | 200 + `user` |
| `POST /auth/password/forgot` | ya | `email` | 202 selalu (tidak membocorkan email terdaftar atau tidak) |
| `POST /auth/password/reset` | ya | `email`, `code`, `new_password` | 204, semua refresh token user dicabut |
| `POST /auth/password/change` | tidak | `current_password`, `new_password` | 204, semua refresh token lain dicabut |

`device_id` dan `device_name` diambil dari header `X-Device-ID` dan `X-Device-Name`.

Kode verifikasi email dan reset password: 6 digit angka, berlaku 15 menit, maksimal 5 percobaan salah, hanya kode terbaru per tujuan yang berlaku.

## 3. User

| Method & path | Body | Sukses |
| --- | --- | --- |
| `GET /me` | – | 200 `{ "user": …, "entitlement": … }` |
| `PATCH /me` | `name` | 200 `{ "user": … }` |

Objek `user` di `GET/PATCH /me` identik dengan objek `user` di respons token (§2). Objek `entitlement` satu skema `Entitlement` (§6) dan sama dengan `meta.entitlement` di pull.
| `DELETE /me` | `confirmation`: password (user email) atau `"HAPUS"` (user sosial) | 202, status `pending_deletion`, semua token dicabut |

Pengaturan (`user_settings`) diubah lewat sync, bukan endpoint ini.

## 4. Sync

| Method & path | Keterangan |
| --- | --- |
| `POST /sync/push` | Lihat `SYNC_PROTOCOL.md` §8. Header `Idempotency-Key` wajib |
| `GET /sync/pull?since=&limit=` | Lihat `SYNC_PROTOCOL.md` §9 |

## 5. Laporan (`report`)

Dipakai untuk verifikasi server dan versi web nanti. App menghitung laporan sendiri dari database lokal.

| Method & path | Akses | Respons |
| --- | --- | --- |
| `GET /reports/monthly?month=YYYY-MM` | Free dalam batas riwayat, premium semua | `monthly_summary`, `accounts`, `totals`, `budget` (struktur sama dengan `expected` di contoh perhitungan `BUSINESS_RULES.md` §9.1) + `expense_by_category` + `income_by_category` |
| `GET /reports/trend?months=6` | Premium | Array per bulan: `month`, `income`, `expense`, `surplus`, `savings`, `adjustments` |

## 6. Billing

| Method & path | Auth | Keterangan |
| --- | --- | --- |
| `GET /me/entitlements` | user | Skema `Entitlement`: `{ "premium": true, "expires_at": "…", "will_renew": true, "product_id": "premium_monthly", "store": "app_store" }` |

Skema `Entitlement` satu untuk semua tempat (`GET /me`, `GET /me/entitlements`, `meta.entitlement` di pull): `premium`, `expires_at`, `will_renew` selalu ada; `product_id` dan `store` opsional (hanya bila ada langganan; pull boleh menghilangkannya).
| `POST /billing/webhooks/revenuecat` | `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>` | Simpan event (idempoten via `event.id`), proses, balas 200. Event yang gagal diproses tetap dibalas 200 setelah tersimpan, dengan `error` terisi untuk diinvestigasi |

## 7. Internal (Vercel Cron)

Vercel Cron memanggil dengan **GET** dan header `Authorization: Bearer <CRON_SECRET>`. Jadwal dalam UTC, hanya berjalan di deployment production, tidak di-retry bila gagal, sehingga job harus idempoten.

| Method & path | Jadwal (UTC) | Tugas |
| --- | --- | --- |
| `GET /internal/cron/recurring` | `0 18 * * *` (01.00 WIB) | Buat kemunculan transaksi berulang yang jatuh tempo (`BUSINESS_RULES.md` §5) per user, dengan advisory lock per user |
| `GET /internal/cron/maintenance` | `30 18 * * *` (01.30 WIB) | Hapus `sync_idempotency_keys` > 24 jam, refresh/verification token kedaluwarsa > 7 hari, dan hapus permanen user `pending_deletion` > 30 hari |

## 8. Lain-lain

| Method & path | Keterangan |
| --- | --- |
| `GET /healthz` | Publik, di luar `/v1`. Cek database dengan timeout maksimal 2 detik. `200 {"status":"ok"}` bila terjangkau, `503 {"status":"unavailable"}` bila tidak. Tanpa detail error di respons (detail hanya di log) |
