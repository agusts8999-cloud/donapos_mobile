import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:flutter/foundation.dart';

class StorageUtils {
  static const double minFreeSpaceMB = 2048; // 2 GB in MB

  static Future<double> getFreeSpaceMB() async {
    if (kIsWeb) return 10240; // Simulated 10GB for Web to pass check
    try {
      double? freeSpace = await DiskSpace.getFreeDiskSpace;
      return freeSpace ?? 0;
    } catch (e) {
      print("Error checking storage: $e");
      return 0;
    }
  }

  static Future<bool> isStorageLow() async {
    double freeSpace = await getFreeSpaceMB();
    return freeSpace < minFreeSpaceMB;
  }

  static Future<void> checkStorageAndWarn(BuildContext context) async {
    bool low = await isStorageLow();
    if (low) {
      if (!context.mounted) return;
      await showStorageInfo(context);
    }
  }

  static Future<void> showStorageInfo(BuildContext context) async {
    double freeSpace = await getFreeSpaceMB();
    double freeGB = freeSpace / 1024;
    bool low = freeSpace < minFreeSpaceMB;
    
    if (context.mounted) {
      showAppModal(
        context,
        title: low ? 'PERINGATAN STORAGE' : 'STATUS PENYIMPANAN',
        message: 'KAPASITAS TERSEDIA: ${freeGB.toStringAsFixed(2)} GB\n'
            'MINIMAL DIBUTUHKAN: 2.00 GB\n\n'
            '${low ? "RUANG PENYIMPANAN SANGAT RENDAH! Mohon hapus beberapa file agar sistem berjalan lancar." : "Kapasitas penyimpanan mencukupi untuk proses backup dan sinkronisasi."}',
        isError: low,
      );
    }
  }
}
