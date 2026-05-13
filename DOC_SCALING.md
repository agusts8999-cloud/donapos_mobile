# Dokumentasi Sistem Scaling Responsif DonaPOS

Sistem ini dirancang untuk memastikan aplikasi DonaPOS Mobile tampil proporsional di berbagai resolusi tablet, dengan basis desain **1340x800**.

## 1. Persiapan (Setup)

Pastikan class `ScreenScaler` sudah diinisialisasi pada awal aplikasi atau pada setiap Screen utama.

```dart
// Di dalam State class Screen Anda
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // Inisialisasi scaler (menghitung screen size saat ini)
  ScreenScaler.init(context);
}
```

## 2. Cara Penggunaan di UI

Gunakan extension `.sp` (untuk font/teks) dan `.sc` (untuk ukuran dimensi seperti padding, margin, lebar, tinggi, radius).

### Contoh Dasar:
Ukuran yang Anda masukkan adalah ukuran sesuai desain di resolusi **1340x800**.

```dart
// Text
Text('Halo Dunia', style: TextStyle(fontSize: 16.sp));

// Box / Container
Container(
  width: 200.sc,
  height: 100.sc,
  padding: EdgeInsets.all(16.sc),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10.sc),
  ),
);

// Spacing
SizedBox(height: 20.sc);

// Icons
Icon(Icons.add, size: 24.sc);
```

## 3. Fitur Auto vs Manual Scale

Sistem mendukung perpindahan mode scaling secara runtime.

```dart
// Pindah ke Manual Scale 150%
await ScreenScaler.updateScaling(isManual: true, manualScale: 1.5);

// Kembali ke Auto Scale (Default)
await ScreenScaler.updateScaling(isManual: false);
```

## 4. Penjelasan Rumus

Scaler menggunakan rumus **Uniform Scaling**:
1. Menghitung `scaleWidth` (W_sekarang / 1340)
2. Menghitung `scaleHeight` (H_sekarang / 800)
3. Menggunakan `min(scaleWidth, scaleHeight)` untuk menghindari elemen meluap (overflow) pada aspek rasio yang berbeda.

Hal ini menjamin desain tetap proporsional (aspect ratio terjaga) meskipun dijalankan di tablet 16:10, 16:9, atau 4:3.
