import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BackupService {
  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
         // Android 11+
         var status = await Permission.manageExternalStorage.status;
         if (!status.isGranted) {
            status = await Permission.manageExternalStorage.request();
         }
         return status.isGranted || await Permission.storage.isGranted;
      }
    }
    
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  static Future<void> autoBackup({int maxBackups = 50}) async {
    try {
      if (!await _requestPermission()) return; // Fail silent

      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final dbPath = await getDatabasesPath();
      final pathDb = p.join(dbPath, 'donapos_v11.db');
      final dbFile = File(pathDb);

      if (!dbFile.existsSync()) return;

      // Use a consistent folder for auto backups
      final dir = Directory('/storage/emulated/0/DonaPOS_Backups/Auto');
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
      final fileName = "AUTO_BACKUP_$timestamp.db";
      final backupPath = p.join(dir.path, fileName);
      
      await dbFile.copy(backupPath);
      
      // Cleanup old files
      final files = dir.listSync().whereType<File>().where((f) => p.basename(f.path).startsWith('AUTO_BACKUP')).toList();
      if (files.length > maxBackups) {
        files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        final diff = files.length - maxBackups;
        for (int i = 0; i < diff; i++) {
          try { await files[i].delete(); } catch (_) {}
        }
      }
    } catch (e) {
      print("Auto Backup Error: $e");
    }
  }

  static Future<void> quickBackup(BuildContext context) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final dbPath = await getDatabasesPath();
      final pathDb = p.join(dbPath, 'donapos_v11.db');
      final dbFile = File(pathDb);

      if (!dbFile.existsSync()) {
        if (context.mounted) {
          showAppModal(context, title: 'GAGAL', message: 'DATABASE TIDAK DITEMUKAN', isError: true);
        }
        return;
      }

      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
      
      final dir = await getApplicationDocumentsDirectory();
      final backupFolder = Directory(p.join(dir.path, 'backups', 'BK_$timestamp'));
      if (!backupFolder.existsSync()) {
        await backupFolder.create(recursive: true);
      }

      final fileName = "DB_DONAPOS_$timestamp.db";
      final backupPath = p.join(backupFolder.path, fileName);
      
      await dbFile.copy(backupPath);
      
      if (context.mounted) {
        showAppModal(context, title: 'ONE-CLICK BACKUP', message: 'CADANGAN TELAH DIBUAT!\nFOLDER: BK_$timestamp\nFILE: $fileName');
      }
    } catch (e) {
      if (context.mounted) {
        showAppModal(context, title: 'ERROR BACKUP', message: e.toString(), isError: true);
      }
    }
  }

  static Future<void> backupDatabase(BuildContext context) async {
    // Request permission first
    if (!await _requestPermission()) {
        if (context.mounted) {
            showAppModal(context, title: 'IJIN DITOLAK', message: 'Aplikasi membutuhkan ijin penyimpanan untuk menyimpan data backup. Silakan aktifkan di Pengaturan.', isError: true);
            openAppSettings();
        }
        return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final dbPath = await getDatabasesPath();
      final pathDb = p.join(dbPath, 'donapos_v11.db');
      final dbFile = File(pathDb);

      if (!dbFile.existsSync()) {
        if (context.mounted) {
          showAppModal(context, title: 'GAGAL', message: 'DATABASE TIDAK DITEMUKAN', isError: true);
        }
        return;
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return;

      final now = DateTime.now();
      final dateStr = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
      final timeStr = "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
      final fileName = "BACKUP_DONAPOS_${dateStr}_$timeStr.db";
      final backupPath = p.join(selectedDirectory, fileName);
      
      await dbFile.copy(backupPath);
      if (context.mounted) {
        showAppModal(context, title: 'BERHASIL', message: 'CADANGAN TERSIMPAN:\n$fileName\n\nDI FOLDER:\n$selectedDirectory');
      }
    } catch (e) {
      if (context.mounted) {
        showAppModal(context, title: 'ERROR', message: e.toString(), isError: true);
      }
    }
  }

  static Future<void> restoreDatabase(BuildContext context) async {
    // Check permission
    if (!await _requestPermission()) {
       if (context.mounted) {
          showAppModal(context, title: 'IJIN DITOLAK', message: 'Aplikasi membutuhkan akses penyimpanan untuk membaca file backup.', isError: true);
          openAppSettings();
       }
       return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null) return;

      final filePath = result.files.single.path!;
      final extension = p.extension(filePath);
      
      if (extension.toLowerCase() != '.db') {
         if (context.mounted) {
           showAppModal(context, title: 'GAGAL', message: 'FILE HARUS BERFORMAT .DB', isError: true);
         }
         return;
      }

      // Confirm before restore
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('KONFIRMASI RESTORE', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('DATA SAAT INI AKAN DIHAPUS DAN DIGANTI DENGAN FILE CADANGAN INI. LANJUTKAN?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('YA, RESTORE', style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (confirm != true) return;
      }

      showPowerfulLoader(context, message: 'MERESTORE DATABASE...');

      await DatabaseHelper.instance.closeDB();

      final dbPath = await getDatabasesPath();
      final targetPath = p.join(dbPath, 'donapos_v11.db');
      final walPath = p.join(dbPath, 'donapos_v11.db-wal');
      final shmPath = p.join(dbPath, 'donapos_v11.db-shm');
      
      // Safety: Delete existing WAL/SHM files to prevent corruption with the new DB
      if (await File(walPath).exists()) await File(walPath).delete();
      if (await File(shmPath).exists()) await File(shmPath).delete();

      final selectedFile = File(filePath);
      if (!await selectedFile.exists()) {
        throw Exception("File backup tidak ditemukan di path: $filePath");
      }
      
      await selectedFile.copy(targetPath);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loader
        showAppModal(context, title: 'BERHASIL', message: 'RESTORE SELESAI.\n\nAplikasi akan ditutup. Silakan buka kembali aplikasi untuk memuat data yang baru.');
        await Future.delayed(const Duration(seconds: 2));
        exit(0); // Exit app to ensure clean DB reload on next start
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loader if open
        showAppModal(context, title: 'ERROR', message: e.toString(), isError: true);
      }
    }
  }
}
