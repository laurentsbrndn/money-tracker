# Business Rules

Semua rumus di dokumen ini diimplementasikan **identik** di backend (Go), Flutter (Dart), dan iOS (Swift) sebagai kode murni tanpa I/O. Contoh di §9.3 (`contracts/fixtures/business_rules/01_monthly_basic.json`) adalah acuan hasil yang benar untuk pengujian manual oleh user.

## 1. Periode dan waktu

- Periode laporan = **bulan kalender** (`YYYY-MM`) di timezone user (`user_settings.timezone`).
- "Hari ini" = tanggal saat ini di timezone user, bukan UTC.
- `transaction_date` disimpan sebagai tanggal kalender; transaksi pukul 00.30 WIB tanggal 1 dicatat dengan tanggal 1 itu.
- Mengganti timezone tidak mengubah `transaction_date` yang sudah ada.

## 2. Data default

### 2.1 Kategori default (dibuat saat register)

| Tipe | Nama | `icon` | `default_allocation` | `sort_order` |
| --- | --- | --- | --- | --- |
| expense | Makan & Minum | `food` | needs | 1 |
| expense | Transportasi | `transport` | needs | 2 |
| expense | Tempat Tinggal | `home` | needs | 3 |
| expense | Tagihan & Utilitas | `bill` | needs | 4 |
| expense | Kesehatan | `health` | needs | 5 |
| expense | Pendidikan | `education` | needs | 6 |
| expense | Biaya Admin | `fee` | needs | 7 |
| expense | Belanja | `shopping` | wants | 8 |
| expense | Hiburan | `entertainment` | wants | 9 |
| expense | Langganan | `subscription` | wants | 10 |
| expense | Jajan & Nongkrong | `snack` | wants | 11 |
| expense | Hadiah & Donasi | `gift` | wants | 12 |
| expense | Investasi | `investment` | savings | 13 |
| expense | Lainnya | `other` | wants | 14 |
| income | Gaji | `salary` | – | 1 |
| income | Freelance | `freelance` | – | 2 |
| income | Bonus | `bonus` | – | 3 |
| income | Hadiah | `gift` | – | 4 |
| income | Lainnya | `other` | – | 5 |

Warna default per ikon didefinisikan di design system masing-masing app; server menyimpan nilai hex yang dikirim saat seed (`#` + 6 digit, daftar di `backend/internal/modules/category/internal/service/default_categories.go`).

Kategori **Biaya Admin** ditandai sebagai kategori sistem untuk biaya transfer: app mencarinya berdasarkan `icon = fee` dan `is_default = true`.

### 2.2 Akun dan budget default

- Akun `Cash` (`type = cash`, saldo awal 0).
- Budget goal 50/30/20 mulai bulan register.

### 2.3 Snapshot saldo awal

Setiap kali akun dibuat, client juga membuat `balance_snapshots` pertama: `snapshot_date = opening_date`, `amount = opening_balance`. Jadi setiap akun selalu punya minimal satu snapshot.

## 3. Transaksi yang dihitung

Sebuah transaksi **ikut dihitung** dalam rumus apa pun hanya bila:

1. `deleted_at` null,
2. `status = posted`,
3. `transaction_date` ≤ tanggal acuan (`as_of`) perhitungan.

Transaksi `pending_confirmation` dan transaksi bertanggal masa depan tidak dihitung sampai statusnya `posted` dan tanggalnya tiba.

## 4. Rumus

Notasi: Σ = jumlah semua transaksi yang memenuhi §3 dan filter yang disebut.

### 4.1 Ringkasan bulan M (poin 2)

```
income(M)   = Σ amount   where type = income  and transaction_date in M
expense(M)  = Σ amount   where type = expense and transaction_date in M
surplus(M)  = income(M) − expense(M)
```

Transfer dan adjustment **tidak** masuk income maupun expense.

### 4.2 Expected balance akun A pada tanggal d

```
E(A, d) = opening_balance(A)
        + Σ amount where type = income     and account_id = A
        − Σ amount where type = expense    and account_id = A
        − Σ amount where type = transfer   and account_id = A
        + Σ amount where type = transfer   and to_account_id = A
        + Σ amount where type = adjustment and account_id = A      (amount bertanda)
        dengan semua transaksi transaction_date ∈ [opening_date(A), d]
```

- Expected total pada tanggal d = Σ E(A, d) untuk akun dengan `include_in_total = true` dan `deleted_at` null (termasuk yang diarsipkan).
- Saldo awal bulan M = expected total pada hari terakhir bulan sebelum M.
- Akun yang `opening_date`-nya setelah tanggal itu tetap dihitung dengan `opening_balance`-nya (rumus E(A, d) tanpa transaksi), jadi membuka akun baru mengubah saldo awal bulan sebelumnya.

### 4.3 Uang aktual (poin 3)

- Snapshot terbaru akun A = snapshot dengan `snapshot_date` terbesar (lalu `updated_at` terbesar) yang `deleted_at` null dan `snapshot_date` ≤ `as_of`.
- `actual_accounts` = Σ snapshot terbaru akun bertipe `bank`, `e_wallet`, `savings`.
- `actual_cash` = Σ snapshot terbaru akun bertipe `cash`.
- `actual_total` = `actual_accounts` + `actual_cash`.
- Hanya akun dengan `include_in_total = true` dan `deleted_at` null.

### 4.4 Selisih (poin 4)

```
diff(A)    = snapshot_terbaru(A).amount − E(A, snapshot_terbaru(A).snapshot_date)
diff_total = Σ diff(A)
```

Status per akun:

| Kondisi | Status |
| --- | --- |
| Snapshot terbaru lebih tua dari 7 hari dari `as_of` | `stale` |
| `diff = 0` | `matched` |
| `diff ≠ 0` | `mismatch` |

`stale` diperiksa lebih dulu. Akun `stale` tetap dijumlahkan ke `diff_total`.

Batas `stale`: `as_of − snapshot_date > 7` hari berarti `stale`. Snapshot yang tepat 7 hari lalu belum `stale`.

Akun tanpa snapshot sama sekali (seharusnya tidak terjadi, lihat §2.3) berstatus `stale` dengan nominal dan `diff` 0, dan tidak ikut `actual_accounts`/`actual_cash`.

### 4.5 Budget bulan M (poin 5)

Goal yang berlaku = `budget_goals` dengan `effective_month` terbesar ≤ bulan M.

```
basis(M)            = max(planned_income ?? 0, income(M))
needs(M)            = Σ amount where type = expense and allocation = needs   and date in M
wants(M)            = Σ amount where type = expense and allocation = wants   and date in M
savings_expense(M)  = Σ amount where type = expense and allocation = savings and date in M
savings_transfer(M) = Σ transfer non-savings → savings − Σ transfer savings → non-savings   (date in M)
savings(M)          = savings_expense(M) + savings_transfer(M)
unallocated(M)      = basis(M) − needs(M) − wants(M) − savings(M)
```

- "Akun savings" ditentukan dari `accounts.type` **saat perhitungan dilakukan**. Mengubah tipe akun berarti riwayat dihitung ulang dengan tipe baru.
- Transfer savings → savings dan non-savings → non-savings bernilai 0 untuk savings.
- `savings(M)` bisa negatif bila lebih banyak menarik dari tabungan daripada menabung.

Per alokasi X ∈ {needs, wants, savings}:

```
goal_amount(X)   = round_half_up(basis × pct(X) / 100)
actual_bp(X)     = round_half_up(actual(X) × 10000 / basis)      → basis point, 1941 = 19,41%
remaining(X)     = goal_amount(X) − actual(X)
```

- Bila `basis = 0`: `actual_bp` = null dan `goal_amount` = 0; UI hanya menampilkan nominal.
- Bila tidak ada goal yang berlaku untuk bulan M, ketiga persentase dianggap 0 sehingga `goal_amount` = 0.
- `round_half_up(p / q)` untuk bilangan bulat: `(p × 2 + q) / (q × 2)` dengan pembagian integer (untuk p ≥ 0). Untuk p < 0: `−round_half_up(−p / q)`.
- Persen ditampilkan dengan 1 desimal hanya di UI (`1941` → `19,4%`).

Peringatan: notifikasi saat `actual(needs)` atau `actual(wants)` melewati 80% lalu 100% dari `goal_amount`, maksimal sekali per ambang per bulan.

### 4.6 Laporan

- Pengeluaran per kategori bulan M: Σ expense dikelompokkan `category_id`, urut nominal menurun.
- Pemasukan per kategori dan per `source` bulan M.
- Tren: §4.1 dan `savings(M)` untuk 6 atau 12 bulan terakhir.
- Selisih tidak tercatat bulan M: Σ amount adjustment di bulan M (bertanda).

## 5. Transaksi berulang

### 5.1 Tanggal kemunculan

Mulai dari `start_date`, sesuai `frequency` dan `interval_count`:

| Frequency | Kemunculan ke-n |
| --- | --- |
| `daily` | `start_date + n × interval` hari |
| `weekly` | Hari `day_of_week` di setiap `interval` minggu, minggu pertama = minggu yang memuat `start_date` |
| `monthly` | Tanggal `day_of_month` setiap `interval` bulan. Bila bulan itu lebih pendek → hari terakhir bulan (31 → 30 Nov, 28/29 Feb) |
| `yearly` | `month_of_year` + `day_of_month` setiap `interval` tahun, dengan aturan hari terakhir yang sama (29 Feb → 28 Feb di tahun non-kabisat) |

Kemunculan sebelum `start_date` atau setelah `end_date` diabaikan.

`weekly` selalu memakai minggu ISO (Senin = 1 … Minggu = 7), **tidak** mengikuti `user_settings.week_start`. ID kemunculan bersifat deterministik dan harus sama di semua device, sehingga tanggal kemunculan tidak boleh bergeser bila user mengubah preferensi awal minggu.

### 5.2 Pembuatan

Dijalankan oleh client saat app dibuka dan oleh cron harian di server, dengan logika sama:

1. Lewati bila `is_paused`, `deleted_at` terisi, atau user tidak premium.
2. Hitung semua kemunculan dengan tanggal > `last_generated_date` (atau ≥ `start_date` bila null) dan ≤ hari ini (timezone user).
3. Untuk setiap kemunculan: ID = UUIDv5(`NS_RECURRING_OCCURRENCE`, `"<rule_id>|<YYYY-MM-DD>"`). Bila baris dengan ID itu **sudah ada (termasuk yang dihapus)** → lewati.
4. Buat transaksi dari template rule dengan `transaction_date` = tanggal kemunculan, `recurring_rule_id` = rule, `status` = `posted` (mode `auto`) atau `pending_confirmation` (mode `confirm`).
5. Set `last_generated_date` = tanggal kemunculan terakhir yang diproses.

Konfirmasi pending: user memilih **Catat** (`status → posted`, nominal/tanggal boleh diubah) atau **Lewati** (transaksi di-soft delete).

## 6. Validasi

Dicek di client sebelum menyimpan dan **diulang di server** saat push.

| Entitas | Aturan |
| --- | --- |
| transactions | `amount`: income/expense/transfer > 0; adjustment ≠ 0; nilai absolut ≤ 999.999.999.999 |
| transactions | `transaction_date` ≥ `opening_date` akun (dan akun tujuan untuk transfer); ≤ hari ini + 366 hari |
| transactions | `account_id` (dan `to_account_id`) milik user; boleh akun yang diarsipkan; tidak boleh akun yang dihapus |
| transactions | `type = transfer` → `to_account_id` wajib dan ≠ `account_id`; `category_id`, `allocation`, `source` null |
| transactions | `type = expense` → `category_id` (kategori expense milik user) dan `allocation` wajib; `to_account_id`, `source` null |
| transactions | `type = income` → `category_id` opsional (kategori income); `allocation`, `to_account_id` null; `source` ≤ 100 karakter |
| transactions | `type = adjustment` → hanya `account_id`, `amount`, `transaction_date`, `note` |
| transactions | `linked_transaction_id` hanya untuk expense dan harus merujuk transfer milik user |
| transactions | `note` ≤ 255 karakter |
| accounts | `name` 1–50 karakter, `type` valid, `opening_date` ≤ hari ini |
| accounts | Tidak boleh dihapus (`deleted_at`) bila masih ada transaksi aktif yang merujuknya; hanya boleh diarsipkan |
| categories | `name` 1–50 karakter, unik per user + type (case-insensitive, di antara yang belum dihapus) |
| categories | Expense wajib `default_allocation`; income harus null |
| categories | Tidak boleh dihapus bila dipakai transaksi aktif; hanya diarsipkan |
| balance_snapshots | `account_id` milik user; `snapshot_date` ≥ `opening_date` akun dan ≤ hari ini |
| budget_goals | `needs_pct + wants_pct + savings_pct = 100`, masing-masing 0–100; `effective_month` tanggal 1; `planned_income` ≥ 0 bila diisi |
| recurring_rules | Field wajib sesuai `frequency`; `end_date` ≥ `start_date`; template lolos validasi transaksi |
| user_settings | `timezone` nama IANA valid; `daily_reminder_time` format `HH:MM` |

## 7. Batas paket

| Fitur | Free | Premium | Ditegakkan di |
| --- | --- | --- | --- |
| Akun aktif (belum dihapus, belum diarsipkan) | maks 4 | tanpa batas | client + server (push) |
| Kategori custom (`is_default = false`, belum dihapus) | maks 5 | tanpa batas | client + server (push) |
| Bulan yang bisa dilihat | bulan berjalan + 2 bulan sebelumnya | semua | client + endpoint laporan server |
| Tren, perbandingan, selisih tidak tercatat, export | – | ya | client + endpoint laporan server |
| Recurring rules (buat/aktifkan) | – | ya | client + server (push) |

- Saat premium berakhir: data tidak dihapus, akun/kategori ekstra tetap bisa dipakai tetapi tidak bisa menambah yang baru, `recurring_rules` di-pause oleh server.
- Client menganggap premium aktif sampai `expires_at` + 3 hari toleransi offline.

## 8. Edge case

| Kasus | Aturan |
| --- | --- |
| Saldo akun negatif | Diizinkan, ditampilkan merah |
| Bunga tabungan masuk akun `savings` | Dicatat sebagai income; tidak menambah `savings(M)` |
| Expense dibayar dari akun `savings` | Dihitung sesuai alokasinya; tidak mengurangi `savings(M)` |
| Tipe akun diubah ke/dari `savings` | Seluruh riwayat dihitung ulang dengan tipe baru (§4.5) |
| Snapshot untuk tanggal lampau | Diizinkan; selisih dibandingkan dengan E pada tanggal snapshot itu |
| Dua snapshot di tanggal sama | Yang `updated_at` terbaru dipakai |
| Edit/hapus transaksi lama | Expected dan selisih otomatis berubah; snapshot tidak berubah |
| Transaksi offline ke akun yang baru diarsipkan device lain | Diterima |
| Mata uang selain IDR | Tidak didukung di MVP |

## 9. Contoh perhitungan (data acuan)

File JSON di sini adalah data acuan, bukan file test. Tidak ada kode test yang membacanya.

### 9.1 Lokasi dan format

`contracts/fixtures/business_rules/<nn>_<nama>.json`:

```json
{
  "name": "string",
  "description": "string",
  "input": {
    "timezone": "Asia/Jakarta",
    "as_of": "YYYY-MM-DD",
    "month": "YYYY-MM",
    "accounts": [],
    "categories": [],
    "transactions": [],
    "balance_snapshots": [],
    "budget_goals": []
  },
  "expected": {
    "monthly_summary": { "income": 0, "expense": 0, "surplus": 0, "opening_total": 0 },
    "accounts": [ { "id": "…", "expected_balance": 0, "latest_snapshot_amount": 0, "latest_snapshot_date": "…", "diff": 0, "status": "matched" } ],
    "totals": { "expected_total": 0, "actual_accounts": 0, "actual_cash": 0, "actual_total": 0, "diff_total": 0 },
    "budget": {
      "basis": 0,
      "needs":   { "goal_amount": 0, "actual": 0, "actual_bp": 0, "remaining": 0 },
      "wants":   { "goal_amount": 0, "actual": 0, "actual_bp": 0, "remaining": 0 },
      "savings": { "goal_amount": 0, "actual": 0, "actual_bp": 0, "remaining": 0 },
      "unallocated": 0
    }
  }
}
```

`expected_balance` di `expected.accounts` dihitung pada `as_of`. Contoh memakai ID pendek yang dibaca sebagai string (misal `"acc-bca"`), bukan UUID.

### 9.2 Contoh tambahan (hanya bila user meminta)

| File | Kasus |
| --- | --- |
| `02_adjustments.json` | Adjustment positif/negatif, tidak masuk income/expense |
| `03_excluded_rows.json` | Transaksi terhapus, pending_confirmation, tanggal masa depan |
| `04_planned_income.json` | `planned_income` > income aktual dan basis = 0 |
| `05_savings_edges.json` | savings → savings, savings → non-savings, expense dari akun savings, expense alokasi savings |
| `06_goal_history.json` | Goal berganti di tengah tahun, bulan lama tetap memakai goal lama |
| `07_rounding.json` | Pembulatan `goal_amount` dan `actual_bp` di angka .5 |
| `08_recurring_dates.json` | Tanggal kemunculan monthly 31, yearly 29 Feb, weekly interval 2 (format `expected.occurrences`) |

### 9.3 Contoh: `01_monthly_basic.json`

Input (bulan November 2026, `as_of` = 2026-11-30, goal 50/30/20 sejak Oktober, tanpa `planned_income`):

| Akun | Tipe | Saldo awal (1 Okt) |
| --- | --- | --- |
| `acc-cash` | cash | 500.000 |
| `acc-bca` | bank | 5.000.000 |
| `acc-jago` | savings | 2.000.000 |

| ID | Tanggal | Tipe | Akun | Nominal | Alokasi | Keterangan |
| --- | --- | --- | --- | --- | --- | --- |
| t0a | 2026-10-25 | income | bca | 8.000.000 | – | Gaji Oktober |
| t0b | 2026-10-26 | expense | bca | 1.500.000 | needs | Kos Oktober |
| t1 | 2026-11-03 | expense | cash | 50.000 | needs | Makan |
| t2 | 2026-11-10 | expense | bca | 300.000 | wants | Hiburan |
| t3 | 2026-11-25 | income | bca | 8.000.000 | – | Gaji |
| t4 | 2026-11-25 | transfer | bca → jago | 1.000.000 | – | Menabung |
| t5 | 2026-11-25 | expense | bca | 2.500 | needs | Biaya admin t4 |
| t6 | 2026-11-26 | expense | bca | 1.500.000 | needs | Kos |
| t7 | 2026-11-28 | transfer | jago → cash | 200.000 | – | Tarik tabungan |
| t8 | 2026-11-12 | expense | cash | 999.999 | wants | Terhapus (`deleted_at` terisi) |
| t9 | 2026-11-20 | expense | bca | 100.000 | wants | `pending_confirmation` |

Snapshot: tiga snapshot saldo awal 2026-10-01, ditambah `acc-cash` 600.000 (2026-11-30) dan `acc-bca` 16.697.500 (2026-11-28).

Expected:

| Hasil | Nilai |
| --- | --- |
| income / expense / surplus | 8.000.000 / 1.852.500 / 6.147.500 |
| opening_total (akhir Oktober) | 14.000.000 |
| E(cash) / E(bca) / E(jago) per 30 Nov | 650.000 / 16.697.500 / 2.800.000 |
| expected_total | 20.147.500 |
| diff cash / bca / jago | −50.000 (`mismatch`) / 0 (`matched`) / 0 (`stale`, snapshot 1 Okt) |
| actual_accounts / actual_cash / actual_total | 18.697.500 / 600.000 / 19.297.500 |
| diff_total | −50.000 |
| basis | 8.000.000 |
| needs: goal / actual / bp / remaining | 4.000.000 / 1.552.500 / 1941 / 2.447.500 |
| wants: goal / actual / bp / remaining | 2.400.000 / 300.000 / 375 / 2.100.000 |
| savings: goal / actual / bp / remaining | 1.600.000 / 800.000 / 1000 / 800.000 |
| unallocated | 5.347.500 |

Catatan: `actual_total` (19.297.500) ≠ `expected_total` (20.147.500) karena snapshot `acc-jago` sudah lama. Inilah alasan selisih dihitung per tanggal snapshot masing-masing akun, bukan total vs total.
