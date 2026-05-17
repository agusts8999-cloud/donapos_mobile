/// Preset sinkronisasi untuk Admin Panel (mode sederhana).
class AdminSyncPreset {
  AdminSyncPreset._();

  /// Unduh data bisnis ke tablet (setup pertama / demo).
  static const List<String> downloadIds = [
    'PRD',
    'IMG',
    'CAT',
    'MOD',
    'STF',
    'PMT',
    'TAB',
    'TXS',
    'DSC',
    'SPG',
    'BIZ',
    'CUS',
    'CGR',
  ];

  /// Kirim data dari tablet ke server (operasional harian).
  static const List<String> postingIds = [
    'EXP',
    'SAL',
    'ATT',
  ];

  static const Map<String, String> friendlyLabels = {
    'PRD': 'Produk & stok',
    'IMG': 'Foto produk',
    'MOD': 'Topping',
    'CAT': 'Kategori',
    'TAB': 'Data meja',
    'STF': 'Kasir & waiter',
    'TXS': 'Pajak & service',
    'DSC': 'Diskon promo',
    'PMT': 'Metode bayar',
    'CUS': 'Data pelanggan',
    'CGR': 'Grup pelanggan',
    'SPG': 'Grup harga jual',
    'BIZ': 'Detail bisnis',
    'XCT': 'Kategori biaya',
    'EXP': 'Kirim biaya',
    'ATT': 'Kirim absensi',
    'SAL': 'Kirim penjualan',
  };

  static String labelFor(String id, String fallback) {
    return friendlyLabels[id] ?? fallback;
  }
}
