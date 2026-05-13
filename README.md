# 📱 DonaPOS Mobile (SaaS Edition) v2.5.0

**Versi Aplikasi: 2.5.0 (SaaS Enterprise Build)**  
*Edisi: Metro UI, Waiter Management & Compact Receipt*

Aplikasi Point of Sales (POS) canggih berbasis Flutter yang merupakan bagian integral dari ekosistem ERP DonaPOS. Didesain dengan filosofi **Offline-First**, **Kecepatan**, dan **Estetika Premium (Metro UI)** untuk bisnis F&B modern.

---

## 🌟 Rekapitulasi Fitur (Total: 15+ Modul Utama)

DonaPOS Mobile bukan sekadar mesin kasir biasa. Berikut adalah **15 Modul Fitur** yang telah tertanam di dalamnya:

1.  **Smart POS Transaction** (Transaksi Cepat, Dine-In/Take-away, Diskon Per Item/Global).
2.  **Table Management System** dengan Layout Meja & Status (Terisi/Kosong).
3.  **Waiter Management (Baru)**: Penugasan pelayan khusus untuk setiap order.
4.  **PAX Counting (Baru)**: Pencatatan jumlah tamu per meja untuk analisis keramaian.
5.  **Multi-Printer System**: Support Printer Kasir (Struk) & Printer Dapur (KOT) via Bluetooth/LAN.
6.  **Offline-First Sync**: Tetap jualan mati lampu/internet, sinkronisasi otomatis saat online.
7.  **Shift Management**: Buka/Tutup Kasir dengan laporan Z-Report & Shift Report.
8.  **Expense Management**: Catat pengeluaran kas kecil (Petty Cash) langsung di POS.
9.  **Attendance System**: Absensi (Clock In/Out) karyawan dengan foto wajah.
10. **Customer Management**: Database pelanggan & riwayat pembelian.
11. **Metro UI Dashboard**: Tampilan modern kotak-kotak (Tiles) yang intuitif & ramah sentuhan.
12. **Multi-Pricing & Tax**: Harga dinamis (Gojek/Grab/DineIn) dan pajak fleksibel.
13. **Split & Merge Bill**: Fitur canggih untuk memisah atau menggabung pembayaran (Hold/Resume).
14. **Advanced Security**: OTP Vendor Protection untuk reset data & PIN akses karyawan.
15. **Multi-Language**: Dukungan Bahasa Indonesia & Inggris.

---

## 📚 Panduan Lengkap Dashboard & Menu

Berikut adalah panduan navigasi berdasarkan ikon yang ada di **Admin Dashboard**:

### � Zona Operasional (Sales)
*   **🛒 KASIR / POS (Icon Keranjang)**
    *   Masuk ke layar utama penjualan.
    *   Tempat melakukan transaksi, input pesanan, pilih meja, dan pembayaran.
*   **📂 TRANSAKSI (Icon Folder)**
    *   Melihat riwayat transaksi yang sudah selesai.
    *   Melakukan Reprint (Cetak Ulang) struk atau Refund*.

### 🔹 Zona Laporan (Reports)
*   **📊 LAPORAN SHIFT (Icon Grafik/Chart)**
    *   Melihat ringkasan penjualan sesi kasir saat ini.
    *   Mencetak Laporan Shift (X-Report) dan Laporan Harian (Z-Report).
*   **💰 PENGELUARAN (Icon Uang)**
    *   Mencatat biaya operasional mendadak (beli es batu, plastik, dll).

### � Zona Sinkronisasi (Sync Center) - *PENTING*
*   **☁️ SINKRONISASI (Icon Awan)**
    *   Pusat keluar-masuk data.
    *   **Posting ke Cloud**: Wajib dilakukan sebelum tutup toko untuk kirim omset ke Owner.
    *   **Ambil Data Produk**: Download menu & harga baru dari kantor pusat.

### � Zona Pengaturan (Settings)
*   **🖨️ PRINTER SETTING (Icon Printer Biru)**
    *   Mengatur koneksi printer kasir utama (Bluetooth).
*   **🍳 PRINTER DAPUR (Icon Restoran Oranye)**
    *   Mengatur printer kedua khusus untuk koki/barista (Bluetooth/LAN).
*   **🖥️ LAYAR PELANGGAN (Icon Monitor Ungu)**
    *   Mengaktifkan layar kedua (jika ada) untuk menampilkan keranjang belanja ke pelanggan.
*   **👤 MANAJEMEN WAITER (Icon Badge/Kartu ID Cyan) - *Baru***
    *   Mendaftarkan staff mana saja yang berstatus sebagai 'Waiter'.
    *   Staff yang aktif di sini akan muncul di pilihan saat order Dine-In.

### 🔹 Zona Aplikasi & Utilitas
*   **ℹ️ TENTANG (Icon Info)**
    *   Cek versi aplikasi dan update terbaru.
*   **🚪 KELUAR (Icon Pintu)**
    *   Log out dari akun admin/kasir untuk ganti pengguna.

---

## 🆕 Fitur Terbaru: Manajemen Meja & Struk Compact

### 1. Input PAX (Jumlah Tamu)
Sekarang, setiap kali kasir memilih Meja, sistem akan memunculkan **Numpad Pop-up** untuk menanyakan jumlah tamu.
*   *Tujuannya:* Mengetahui okupansi kursi restoran.
*   *Tampilan:* Nama meja di layar POS akan otomatis terupdate, misal: **"MEJA 01 (4 P)"**.

### 2. Format Struk Compact
Struk belanja telah direvisi total agar hemat kertas namun padat informasi:
*   **Anti-Spasi:** Mengurangi jarak kosong antar baris.
*   **Info Lengkap:** Menampilkan Nama Waiter, Nama Meja, dan Jumlah Tamu (PAX).
*   **Layout Rapi:** Garis pemisah yang tegas antar bagian.

---

## 🛠️ Cara Setup & Install

### Persyaratan Penggunaan (User Requirements)
*   Tablet Android (Min. Android 10, Rekomendasi 8-10 Inch).
*   Koneksi Internet (Untuk Login awal & Sync).
*   Printer Thermal Bluetooth (Support ESC/POS).

### 🛠️ Kebutuhan Pengembangan (Development Requirements)
Untuk melakukan compile atau pengembangan aplikasi ini, pastikan perangkat Anda memenuhi syarat berikut:

#### 1. Alat Kompilasi (Development Tools)
*   **Flutter SDK**: Versi 3.10.x atau lebih baru (Stable Channel).
*   **Dart SDK**: Terintegrasi dengan Flutter SDK.
*   **Android SDK**: Mendukung API level 21 hingga API level 34.
*   **OpenJDK**: JDK 11 atau 17 (Wajib untuk build Android).
*   **IDE**: Android Studio (direkomendasikan) atau VS Code dengan extension Flutter & Dart.
*   **Git**: Untuk manajemen source code.

#### 2. Spesifikasi Sistem (System Specs)
*   **OS**: macOS (Intel/M-Series), Windows 10/11, atau Linux.
*   **RAM**: Minimal 8GB (16GB sangat direkomendasikan).
*   **Storage**: Minimal 15GB ruang kosong untuk SDK dan Build artifacts.

#### 3. Backend (DonaPOS ERP)
Aplikasi mobile ini membutuhkan backend DonaPOS yang berjalan dengan spesifikasi:
*   **PHP**: Versi 8.0 atau 8.1.
*   **Database**: MySQL 5.7+ atau MariaDB 10.4+.
*   **Composer**: Untuk manajemen dependensi PHP.
*   **Web Server**: Apache/Nginx (XAMPP bisa digunakan untuk development lokal).

---

### 🚀 Cara Compile & Build APK

1.  **Persiapan Dependensi:**
    Buka terminal di direktori `donapos_mobile/` dan jalankan:
    ```bash
    flutter pub get
    ```

2.  **Membersihkan Build Sebelumnya (Opsional):**
    ```bash
    flutter clean
    ```

3.  **Proses Compile APK:**
    Untuk menghasilkan APK yang optimal dan ringan (dipisahkan berdasarkan arsitektur CPU):
    ```bash
    flutter build apk --release --split-per-abi
    ```

4.  **Lokasi Hasil Compile:**
    File APK hasil build dapat ditemukan di:
    `build/app/outputs/flutter-apk/`

### Cara Install/Update
1.  Pastikan semua transaksi lama sudah ter-upload di menu **Sinkronisasi**.
2.  Transfer file `app-release.apk` ke tablet.
3.  Install APK tersebut (Timpa/Update aplikasi lama).
4.  Buka Aplikasi -> Login Ulang.
5.  Masuk ke menu **Sync Center** -> Lakukan **"Ambil Data Produk (Lengkap)"**.

---

*© 2026 DonaPOS Enterprise System. Solusi ERP Kasir Terdepan.*
