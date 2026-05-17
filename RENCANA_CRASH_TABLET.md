# Rencana Perbaikan Crash Tablet (Running Lama)

| Field | Nilai |
|-------|-------|
| Versi dokumen | 1.0 |
| Tanggal | 17 Mei 2026 |
| Aplikasi | DonaPOS Mobile 2.8.0+10225 |
| Gejala | App force-close setelah running beberapa jam; bisa di layar mana pun |
| Catatan audit | [AUDIT_CATATAN.md](AUDIT_CATATAN.md) |
| Rencana umum | [RENCANA_PERBAIKAN.md](RENCANA_PERBAIKAN.md) |

---

## Ringkasan

Crash setelah sesi panjang kemungkinan besar disebabkan kombinasi: **sync overlap** (RAM spike), **rebuild UI berlebihan** (timer 30 detik + setState keranjang), dan **cache gambar** tanpa batas. Perbaikan diimplementasikan di Fase FIX-01 s.d. FIX-11 (lihat checklist di bawah).

---

## Hipotesis penyebab

| ID | Prioritas | Hipotesis | Status investigasi |
|----|-----------|-----------|------------------|
| CRASH-01 | P0 | Sync foreground tanpa await, overlap | Mitigasi: FIX-01 |
| CRASH-02 | P0 | Workmanager tanpa Flutter binding init | Mitigasi: FIX-02 |
| CRASH-03 | P0 | Lock sync tidak cross-isolate | Mitigasi: FIX-03 |
| CRASH-04 | P0 | Consumer PosProvider rebuild tiap 30 detik | Mitigasi: FIX-04 |
| CRASH-05 | P1 | Precache 100 gambar produk | Mitigasi: FIX-07 |
| CRASH-06 | P1 | ImageCache global tanpa batas | Mitigasi: FIX-05, FIX-08 |
| CRASH-07 | P1 | setState full screen tiap ubah keranjang | Mitigasi: FIX-09 |
| CRASH-08 | P1 | Timer marquee animasi kontinu | Belum diubah (dampak rendah) |
| CRASH-09 | P0 | Plugin `flutter_pos_printer_platform`: `bluetoothService` lateinit saat `onDetachedFromEngine` (Workmanager tanpa Activity) | **Diperbaiki** — patch lokal `packages/flutter_pos_printer_platform_image_3` |
| CRASH-10 | P2 | Log file tanpa rotasi ukuran | Backlog |
| CRASH-11 | P2 | Tidak ada crash reporting cloud | Backlog FIX-15 |

---

## Fase 0 — Diagnostik

| ID | Langkah | Status | Catatan |
|----|---------|--------|---------|
| DIAG-01 | Build profile, jalankan 2–4 jam | belum | `flutter run --profile` |
| DIAG-02 | Logcat saat crash | belum | `adb logcat -s flutter,AndroidRuntime` |
| DIAG-03 | DevTools Memory 30 menit | belum | Pantau heap naik terus atau plateau |
| DIAG-04 | Catat spesifikasi tablet | belum | Lihat template di bawah |

### Template hasil logcat

| Waktu | Layar aktif | Pesan error / exception | OOM? | Plugin? |
|-------|-------------|-------------------------|------|---------|
| | | | Ya/Tidak | BT/Sync/Lain |

### Template lingkungan

| Item | Nilai |
|------|-------|
| Model tablet | |
| RAM | |
| Android version | |
| Versi APK | |
| Jumlah produk di DB | |
| Auto-posting interval (menit) | |
| Second screen ON/OFF | |
| Lama running sebelum crash | |

---

## Fase 1 — Quick wins (FIX-01 … FIX-06)

| ID | Task | Status | PR/commit |
|----|------|--------|-----------|
| FIX-01 | Serialize sync foreground (`await`, flag overlap) | selesai | |
| FIX-02 | `WidgetsFlutterBinding` di Workmanager | selesai | |
| FIX-03 | Mutex sync via SQLite `app_settings` | selesai | |
| FIX-04 | `unsyncedCountNotifier` tanpa `notifyListeners` global | selesai | |
| FIX-05 | Batas ImageCache di `main()` | selesai | |
| FIX-06 | Global error handler → LoggerService | selesai | |

### Checklist Fase 1

- [x] FIX-01
- [x] FIX-02
- [x] FIX-03
- [x] FIX-04
- [x] FIX-05
- [x] FIX-06

---

## Fase 2 — Memori & UI POS (FIX-07 … FIX-11)

| ID | Task | Status | PR/commit |
|----|------|--------|-----------|
| FIX-07 | Precache produk 100 → 24 | selesai | |
| FIX-08 | `memCacheWidth` pada CachedNetworkImage | selesai | |
| FIX-09 | ListenableBuilder keranjang, hapus setState global cart | selesai | |
| FIX-10 | Dispose dialog controllers (dialog utama) | selesai | |
| FIX-11 | Pause timer PosProvider saat keluar POS (RouteAware) | selesai | |

### Checklist Fase 2

- [x] FIX-07
- [x] FIX-08
- [x] FIX-09
- [x] FIX-10
- [x] FIX-11

---

## Fase 3 — Verifikasi (FIX-12 … FIX-15)

### Prosedur soak test (manual di tablet)

1. Build release: `flutter build apk --release --split-per-abi`
2. Install di tablet target (RAM dan Android version dicatat di template di atas)
3. Login, buka POS, aktifkan auto-posting seperti produksi
4. Jalankan minimal 4 jam: campur idle, transaksi, cetak struk, buka admin lalu kembali ke POS
5. Pantau logcat: `adb logcat -s flutter,AndroidRuntime`
6. Jika crash: isi tabel logcat; jika stabil 8 jam: centang FIX-12 dan FIX-13

| ID | Task | Status | Kriteria |
|----|------|--------|----------|
| FIX-12 | Soak test 4 jam | menunggu manual | Zero force-close |
| FIX-13 | Soak test 8 jam release APK | menunggu manual | Zero force-close |
| FIX-14 | `largeHeap` (opsional) | ditunda | Hanya jika logcat OOM |
| FIX-15 | Crashlytics/Sentry | backlog | |

### Checklist Fase 3

- [ ] FIX-12 — Soak 4 jam di tablet produksi
- [ ] FIX-13 — Soak 8 jam release APK
- [ ] FIX-14 — largeHeap (jika OOM terkonfirmasi)
- [ ] FIX-15 — Crash reporting

---

## Pemetaan ke RENCANA_PERBAIKAN.md

| Crash | Rencana umum |
|-------|----------------|
| FIX-01, FIX-02, FIX-03 | SYNC-02, SYNC-03 |
| FIX-06 | QA-04 |
| FIX-10 | QA-05 |

---

## Release gate

Sebelum rilis APK ke toko setelah perbaikan ini:

1. FIX-01 … FIX-11 terdeploy
2. `flutter analyze` tanpa error di `lib/`
3. Soak test minimal **4 jam** (FIX-12) tanpa force-close
4. Isi template logcat & lingkungan di dokumen ini

---

## Log perubahan dokumen

| Tanggal | Versi | Perubahan |
|---------|-------|-----------|
| 2026-05-17 | 1.0 | Rilis awal + implementasi FIX-01..11 |
