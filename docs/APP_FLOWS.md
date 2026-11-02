# App Flows

Alur layar yang sama untuk Android dan iOS. Rumus dan validasi ada di `BUSINESS_RULES.md`; perilaku sync di `SYNC_PROTOCOL.md`.

## Flow 1 — Instalasi, registrasi, setup awal

1. **Splash**: cek sesi + database lokal. Ada sesi → Dashboard (walau offline). Tidak ada → Onboarding.
2. **Onboarding** (3 slide, bisa di-skip): catat pemasukan & pengeluaran; cocokkan dengan saldo asli; atur needs/wants/savings.
3. **Masuk / Daftar**:
    1. iOS: Sign in with Apple, Google, email. Android: Google, email.
    2. Daftar email: nama, email, password ≥ 8 karakter. Server mengirim kode verifikasi 6 digit; app tetap bisa dipakai dengan banner "Verifikasi email" sampai terverifikasi.
    3. Lupa password: input email → input kode 6 digit + password baru.
4. Server membuat data awal (`DATA_MODEL.md` §9) dalam satu transaksi.
5. **Initial sync**: layar "Menyiapkan data…" sampai pull selesai.
6. **Setup wizard** (bisa dilewati, hanya untuk user baru):
    1. Isi saldo Cash saat ini (mengubah `opening_balance` akun Cash dan snapshot awalnya).
    2. Tambah akun: tipe, logo (daftar statis: BCA, Mandiri, BRI, BNI, Jago, SeaBank, GoPay, OVO, DANA, ShopeePay, Lainnya), nama, saldo saat ini. Saldo = `opening_balance` + snapshot pertama, `opening_date` = hari ini.
    3. Budget goal: 50/30/20 atau custom (total 100%).
    4. Kategori: sembunyikan yang tidak relevan.
    5. Izin notifikasi + jam pengingat harian.
    6. Opsional: kunci app (PIN/biometrik).
7. **Dashboard** dengan empty state "Catat transaksi pertama".

Login di device kedua: login → initial sync → Dashboard, wizard dilewati.

## Flow 2 — Dashboard bulanan

Dari atas ke bawah:

1. Header: pemilih bulan + `SyncBadge`.
2. Ringkasan bulan: income, expense, surplus.
3. Uang aktual: saldo rekening, cash, total, tanggal update terakhir. Tap → Akun.
4. Selisih: expected vs aktual. Hijau bila 0; kuning bila ada selisih + tombol "Cocokkan"; abu-abu "Update saldo aktual" bila ada akun `stale`.
5. Budget: bar needs/wants/savings (goal vs actual, nominal), belum teralokasi. Wants merah bila melewati goal.
6. 5 transaksi terakhir + "Lihat semua".
7. FAB +.

Bulan di luar batas riwayat paket gratis → paywall.

## Flow 3 — Mencatat transaksi

FAB → tab **Expense** (default) / **Income** / **Transfer**.

- **Expense**: nominal (numpad) → kategori (grid; alokasi terisi dari `default_allocation`, bisa diganti) → akun (default terakhir dipakai) → tanggal (default hari ini) → catatan "buat apa" → Simpan.
- **Income**: nominal → sumber "dari mana" (saran dari riwayat) → kategori income → akun tujuan → tanggal → catatan → Simpan.
- **Transfer**: nominal → dari akun → ke akun (≠ asal) → biaya admin opsional (membuat expense terpisah kategori Biaya Admin dari akun asal, `linked_transaction_id` = transfer) → tanggal → catatan → Simpan. Bila tujuan bertipe `savings`, tampilkan "Tercatat sebagai savings bulan ini".

Simpan = tulis lokal + outbox (`SYNC_PROTOCOL.md` §6), UI langsung ter-update, sync di belakang.

## Flow 4 — Riwayat transaksi

1. Daftar per tanggal (terbaru di atas) dengan subtotal harian. Ikon awan kecil untuk yang belum tersinkron.
2. Filter: tipe, akun, kategori, alokasi, rentang tanggal. Cari: catatan dan sumber.
3. Tap → form edit. Geser → Hapus (soft delete) dengan snackbar "Urungkan" 5 detik. Tekan lama → Duplikat.
4. Section "Menunggu konfirmasi" untuk transaksi berulang mode `confirm` (Catat / Lewati).

## Flow 5 — Akun & rekonsiliasi

**Halaman Akun**: ringkasan uang aktual; daftar akun per tipe dengan saldo aktual terakhir + tanggal, expected balance, badge selisih. Tap → detail (grafik saldo, transaksi akun, riwayat snapshot).

**Form akun**: tipe, logo, nama, saldo awal, tanggal saldo awal, "hitung di total". Akun yang punya transaksi hanya bisa diarsipkan; saat arsip dengan saldo ≠ 0, tawarkan transfer sisa saldo.

**Cocokkan saldo**:

1. Dibuka dari Dashboard, Akun, atau notifikasi akhir bulan.
2. Tampilkan akun aktif dengan expected balance hari ini.
3. User mengisi saldo asli per akun (yang kosong dilewati) → masing-masing disimpan sebagai snapshot hari ini.
4. Per akun: selisih 0 → centang hijau; selisih ≠ 0 → pilih:
    1. **Catat yang terlewat**: buka form transaksi untuk akun itu, selisih dihitung ulang.
    2. **Buat penyesuaian**: transaksi `adjustment` sebesar selisih, catatan "Selisih tidak tercatat".
    3. **Nanti saja**.
5. Ringkasan: jumlah akun cocok dan total yang disesuaikan.

## Flow 6 — Budget

1. **Atur goal**: tiga input persen (total harus 100%), preset 50/30/20, 60/20/20, 40/30/30, rencana income bulanan opsional. Berlaku mulai bulan ini (`effective_month`).
2. **Halaman budget**: per alokasi goal % + nominal, actual % + nominal, sisa/kekurangan; baris belum teralokasi. Tap → rincian per kategori.
3. Peringatan 80% dan 100% untuk needs/wants; kartu evaluasi di akhir bulan.

## Flow 7 — Kategori

Lainnya → Kategori: tab Expense/Income; tambah (nama, ikon, warna, alokasi default untuk expense); ubah (alokasi default hanya untuk transaksi baru); urutkan (drag); sembunyikan/arsipkan; hapus permanen hanya bila belum pernah dipakai.

## Flow 8 — Laporan

Lainnya → Laporan → pilih jenis → pilih bulan/rentang → tap bagian grafik untuk melihat transaksinya. Jenis dan akses free/premium di `BUSINESS_RULES.md` §4.6 dan §7. Dihitung dari database lokal.

## Flow 9 — Subscription

1. Paywall dari: tap fitur premium, batas tercapai, Lainnya → Langganan.
2. Isi: manfaat, paket bulanan/tahunan, trial 7 hari, Pulihkan Pembelian, Syarat & Privasi.
3. Beli → store → RevenueCat → webhook server → app memanggil `GET /v1/me/entitlements` → fitur terbuka.
4. Kelola langganan membuka halaman langganan store.
5. Offline: entitlement cache berlaku sampai `expires_at` + 3 hari. Server menolak push yang melewati batas (`plan_limit`).
6. Premium berakhir: data tetap, tidak bisa menambah di atas batas, recurring di-pause.

## Flow 10 — Transaksi berulang (premium)

1. Dari form transaksi ("Ulangi") atau Lainnya → Transaksi berulang → Tambah.
2. Template transaksi + frekuensi (harian, mingguan, bulanan, tahunan; interval) + tanggal mulai/selesai + mode (otomatis / minta konfirmasi).
3. Kemunculan dibuat saat app dibuka dan oleh cron harian (`BUSINESS_RULES.md` §5).
4. Edit aturan hanya memengaruhi kemunculan berikutnya; hapus aturan tidak menghapus transaksi yang sudah ada.

## Flow 11 — Sinkronisasi

Lihat `SYNC_PROTOCOL.md`. Yang terlihat user: `SyncBadge`, pull-to-refresh, dan layar Pengaturan → Sinkronisasi (waktu sync terakhir, jumlah tertunda, Sync sekarang, daftar "Perlu perhatian" dengan opsi perbaiki atau buang perubahan).

## Flow 12 — Pengaturan, keamanan, akun

| Menu | Isi |
| --- | --- |
| Profil | Nama, email, status verifikasi, metode login, ubah password |
| Preferensi | Timezone, hari pertama minggu, tema |
| Keamanan | PIN 6 digit / biometrik, kunci otomatis setelah 1 menit di background, sembunyikan nominal |
| Notifikasi | Pengingat harian + jam, pengingat cocokkan saldo, peringatan budget |
| Sinkronisasi | Flow 11 |
| Langganan | Status, tanggal perpanjangan, kelola, pulihkan |
| Data | Export (premium) |
| Bantuan | FAQ, kirim masukan, versi app |
| Keluar | Peringatan bila ada perubahan belum tersinkron → cabut refresh token → hapus database lokal |
| Hapus akun | Penjelasan + pengingat batalkan langganan di store → konfirmasi (password atau ketik "HAPUS") → `DELETE /v1/me` → hapus data lokal → Onboarding |

## Notifikasi lokal

| Notifikasi | Kapan | Tap |
| --- | --- | --- |
| Pengingat harian | Jam pilihan user, dilewati bila hari itu sudah ada transaksi | Form transaksi |
| Cocokkan saldo | Hari terakhir bulan 20.00, dan bila ada akun `stale` | Cocokkan saldo |
| Peringatan budget | Needs/wants melewati 80% dan 100% | Budget |
| Konfirmasi berulang | Ada kemunculan mode `confirm` | Menunggu konfirmasi |
| Evaluasi bulan | Tanggal 1 pukul 09.00 | Laporan bulan lalu |
