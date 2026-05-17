import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/models/admin_sync_preset.dart';
import 'package:flutter/foundation.dart';

typedef SyncTask = Future<dynamic> Function({Function(String)? onProgress});

class SyncTaskItem {
  final String id;
  final String label;
  final SyncTask task;

  SyncTaskItem({
    required this.id,
    required this.label,
    required this.task,
  });
}

List<SyncTaskItem> createAdminSyncItems(ApiService api) {
  String label(String id, String fallback) =>
      AdminSyncPreset.labelFor(id, fallback);

  return [
    SyncTaskItem(
      id: 'PRD',
      label: label('PRD', 'Produk & stok'),
      task: ({onProgress}) =>
          api.syncProducts(includeImages: true, force: true, onProgress: onProgress),
    ),
    SyncTaskItem(
      id: 'IMG',
      label: label('IMG', 'Foto produk'),
      task: ({onProgress}) => api.syncProductImages(onProgress: onProgress),
    ),
    SyncTaskItem(
      id: 'MOD',
      label: label('MOD', 'Topping'),
      task: ({onProgress}) => api.syncModifiers(),
    ),
    SyncTaskItem(
      id: 'CAT',
      label: label('CAT', 'Kategori'),
      task: ({onProgress}) => api.syncCategories(),
    ),
    SyncTaskItem(
      id: 'TAB',
      label: label('TAB', 'Data meja'),
      task: ({onProgress}) => api.syncResTables(),
    ),
    SyncTaskItem(
      id: 'STF',
      label: label('STF', 'Kasir & waiter'),
      task: ({onProgress}) => api.syncUsers(),
    ),
    SyncTaskItem(
      id: 'TXS',
      label: label('TXS', 'Pajak & service'),
      task: ({onProgress}) => api.syncTaxes(),
    ),
    SyncTaskItem(
      id: 'DSC',
      label: label('DSC', 'Diskon promo'),
      task: ({onProgress}) => api.syncDiscounts(),
    ),
    SyncTaskItem(
      id: 'PMT',
      label: label('PMT', 'Metode bayar'),
      task: ({onProgress}) => api.syncPaymentMethods(),
    ),
    SyncTaskItem(
      id: 'CUS',
      label: label('CUS', 'Data pelanggan'),
      task: ({onProgress}) => api.syncContacts(onProgress: onProgress),
    ),
    SyncTaskItem(
      id: 'CGR',
      label: label('CGR', 'Grup pelanggan'),
      task: ({onProgress}) => api.syncCustomerGroups(),
    ),
    SyncTaskItem(
      id: 'SPG',
      label: label('SPG', 'Grup harga jual'),
      task: ({onProgress}) => api.syncPriceGroups(),
    ),
    SyncTaskItem(
      id: 'BIZ',
      label: label('BIZ', 'Detail bisnis'),
      task: ({onProgress}) => api.syncBusinessDetails(),
    ),
    SyncTaskItem(
      id: 'XCT',
      label: label('XCT', 'Kategori biaya'),
      task: ({onProgress}) => api.syncExpenseCategories(),
    ),
    SyncTaskItem(
      id: 'EXP',
      label: label('EXP', 'Kirim biaya'),
      task: ({onProgress}) => api.syncExpenses(),
    ),
    SyncTaskItem(
      id: 'ATT',
      label: label('ATT', 'Kirim absensi'),
      task: ({onProgress}) => api.syncAttendances(),
    ),
    SyncTaskItem(
      id: 'SAL',
      label: label('SAL', 'Kirim penjualan'),
      task: ({onProgress}) => api.syncTransactionsWithLogs(),
    ),
  ];
}

class AdminSyncRunResult {
  final bool success;
  final int completed;
  final int total;
  final String? failedLabel;
  final String? errorMessage;

  AdminSyncRunResult({
    required this.success,
    required this.completed,
    required this.total,
    this.failedLabel,
    this.errorMessage,
  });
}

Future<AdminSyncRunResult> runAdminSyncPreset({
  required ApiService api,
  required List<String> presetIds,
  void Function(int current, int total, String label)? onStep,
  void Function(String logLine)? onLog,
}) async {
  final all = createAdminSyncItems(api);
  final queue = all.where((i) => presetIds.contains(i.id)).toList();
  if (queue.isEmpty) {
    return AdminSyncRunResult(success: false, completed: 0, total: 0, errorMessage: 'Tidak ada data untuk diproses.');
  }

  onLog?.call('Memeriksa koneksi...');
  if (!await api.checkConnection()) {
    return AdminSyncRunResult(
      success: false,
      completed: 0,
      total: queue.length,
      errorMessage: 'Tidak ada koneksi internet. Periksa Wi‑Fi tablet.',
    );
  }

  final headers = await api.getHeaders();
  final token = headers['Authorization'];
  if (token == null || token == 'Bearer null') {
    onLog?.call('Login otomatis ke server...');
    final authOk = await api.authenticateClient();
    if (!authOk) {
      return AdminSyncRunResult(
        success: false,
        completed: 0,
        total: queue.length,
        errorMessage: 'Gagal terhubung ke server. Coba lagi atau hubungi admin.',
      );
    }
  }

  var completed = 0;
  for (var i = 0; i < queue.length; i++) {
    final item = queue[i];
    onStep?.call(i + 1, queue.length, item.label);
    onLog?.call('Memproses: ${item.label}...');

    try {
      await item.task(onProgress: (p) {
        onLog?.call('  $p');
      });
      completed++;
      onLog?.call('Selesai: ${item.label}');
    } catch (e, stack) {
      debugPrint('Admin sync error (${item.id}): $e\n$stack');
      return AdminSyncRunResult(
        success: false,
        completed: completed,
        total: queue.length,
        failedLabel: item.label,
        errorMessage: 'Gagal pada "${item.label}". Periksa koneksi lalu coba lagi.',
      );
    }
  }

  return AdminSyncRunResult(
    success: true,
    completed: completed,
    total: queue.length,
  );
}
