import 'dart:io';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/widgets/confirm_dialog.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SdCardBackupScreen extends StatefulWidget {
  final bool allowRestore;
  const SdCardBackupScreen({super.key, this.allowRestore = false});

  @override
  State<SdCardBackupScreen> createState() => _SdCardBackupScreenState();
}

class _SdCardBackupScreenState extends State<SdCardBackupScreen> {
  List<FileSystemEntity> _backups = [];
  bool _isLoading = false;
  String _currentPath = '/storage/emulated/0/DonaPOS_Backups'; // Default fallback

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    // Determine best path. 
    // Usually /storage/emulated/0 is reliable for Internal Storage root.
    // If physical SD card is present, it might be /storage/XXXX-XXXX/.
    // For now we stick to "External Storage" (which usually means the user accessible storage).
    
    // Check Permissions
    await _checkPermission();
    _scan();
  }

  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
           await Permission.manageExternalStorage.request();
        }
      } else {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
           await Permission.storage.request();
        }
      }
    }
  }

  Future<void> _scan() async {
    setState(() => _isLoading = true);
    try {
      final dir = Directory(_currentPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      
      final List<FileSystemEntity> files = dir.listSync()
        .where((e) => e.path.toLowerCase().endsWith('.db')) // Only show DB files
        .toList();
      
      // Sort by modification time desc
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      setState(() {
        _backups = files;
      });
    } catch (e) {
      showAppModal(context, title: 'ERROR SCAN', message: 'Gagal membaca folder backup:\n$e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _backup() async {
    try {
      showPowerfulLoader(context, message: 'MEMBUAT BACKUP...');
      
      final db = await DatabaseHelper.instance.database;
      // Force checkpoint to flush WAL to main DB file
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      
      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'donapos_v11.db');
      final sourceFile = File(sourcePath);

      if (!sourceFile.existsSync()) {
        throw Exception("File Database Sumber tidak ditemukan!");
      }

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = "BACKUP_DONAPOS_$dateStr.db";
      final targetPath = p.join(_currentPath, fileName);
      
      await sourceFile.copy(targetPath);
      
      if (mounted) {
        Navigator.pop(context); // Close loader
        showAppModal(context, title: 'SUKSES', message: 'Backup berhasil dibuat:\n$fileName');
        _scan(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showAppModal(context, title: 'GAGAL', message: e.toString(), isError: true);
      }
    }
  }

  Future<void> _restore(File backupFile) async {
    if (!widget.allowRestore) {
      showAppModal(
        context, 
        title: 'AKSES DITOLAK', 
        message: 'Restore database hanya diperbolehkan melalui menu Admin.', 
        isError: true
      );
      return;
    }

    bool confirm = await showAppConfirm(
      context, 
      title: 'RESTORE DATABASE?', 
      message: 'PERINGATAN: Data saat ini akan DITIMPA/HILANG dan digantikan dengan data dari backup ini.\n\nFile: ${p.basename(backupFile.path)}',
      confirmLabel: 'RESTORE SEKARANG',
    );
    
    if (!confirm) return;
    
    try {
      showPowerfulLoader(context, message: 'MERESTORE...');
      
      // Close DB Connection
      await DatabaseHelper.instance.closeDB();
      
      final dbPath = await getDatabasesPath();
      final targetPath = p.join(dbPath, 'donapos_v11.db');
      
      // Clean up WAL/SHM to avoid corruption mismatch
      final walVal = File('$targetPath-wal');
      final shmVal = File('$targetPath-shm');
      if (walVal.existsSync()) walVal.deleteSync();
      if (shmVal.existsSync()) shmVal.deleteSync();
      
      await backupFile.copy(targetPath);
      
      if (mounted) {
        Navigator.pop(context); // Close loader
        await showAppModal(context, title: 'RESTORE SUKSES', message: 'Aplikasi akan ditutup. Silakan buka kembali untuk memuat data baru.');
        exit(0);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showAppModal(context, title: 'GAGAL RESTORE', message: e.toString(), isError: true);
      }
    }
  }

  Future<void> _format() async {
    bool confirm = await showAppConfirm(
      context, 
      title: 'HAPUS SEMUA BACKUP?', 
      message: 'Tindakan ini akan MENGHAPUS SEMUA file backup yang ada di folder ini.\nPath: $_currentPath',
      confirmLabel: 'FORMAT / HAPUS SEMUA',
    );
    
    if (!confirm) return;
    
    try {
      showPowerfulLoader(context, message: 'MENGHAPUS...');
      final dir = Directory(_currentPath);
      final List<FileSystemEntity> files = dir.listSync();
      for (var f in files) {
        if (f is File && f.path.endsWith('.db')) {
          f.deleteSync();
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
        _scan();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showAppModal(context, title: 'ERROR', message: e.toString(), isError: true);
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    bool confirm = await showAppConfirm(
      context, 
      title: 'HAPUS BACKUP?', 
      message: 'Hapus file backup ini permanen?',
      confirmLabel: 'HAPUS',
    );
    if (!confirm) return;

    try {
      file.deleteSync();
      _scan();
    } catch (e) {
      showAppModal(context, title: 'GAGAL HAPUS', message: e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        title: const Text('SD CARD MANAGEMENT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
        backgroundColor: MetroColors.primary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20), 
            onPressed: () => _scan(),
          )
        ],
      ),
      body: Column(
        children: [
          // Header Status
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: MetroColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.sd_storage, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PENYIMPANAN EKSTERNAL', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(_currentPath, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_backups.length} FILES', style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 10)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.1, // Placeholder for usage percentage
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Action Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('DAFTAR CADANGAN DATA', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey, fontSize: 10, letterSpacing: 1)),
                if (_backups.isNotEmpty)
                  TextButton.icon(
                    onPressed: _format,
                    icon: const Icon(Icons.delete_sweep, size: 16, color: MetroColors.error),
                    label: const Text('BERSIHKAN SEMUA', style: TextStyle(color: MetroColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // List / Grid
          Expanded(
            child: _isLoading 
              ? const Center(child: DonaposLoader(size: 60)) 
              : _backups.isEmpty 
                  ? _buildEmptyState()
                  : isLandscape ? _buildGrid() : _buildList(),
          ),
          
          // Floating-style Bottom Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: SafeArea(
              child: MetroButton(
                label: 'BUAT BACKUP KE SD CARD',
                icon: Icons.add_to_photos,
                color: MetroColors.primary,
                onPressed: _backup,
                isLarge: true,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('BELUM ADA BACKUP', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11)),
          const SizedBox(height: 8),
          const Text('Ketuk tombol di bawah untuk membuat cadangan.', style: TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _backups.length,
      itemBuilder: (context, index) => _buildBackupTile(_backups[index] as File),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _backups.length,
      itemBuilder: (context, index) => _buildBackupTile(_backups[index] as File),
    );
  }

  Widget _buildBackupTile(File file) {
    final stat = file.statSync();
    final sizeMb = (stat.size / (1024 * 1024)).toStringAsFixed(2);
    final date = DateFormat('dd MMM yyyy').format(stat.modified);
    final time = DateFormat('HH:mm').format(stat.modified);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _restore(file),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storage, color: MetroColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.basename(file.path), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 10, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 10, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$sizeMb MB', style: const TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary, fontSize: 10)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _deleteBackup(file),
                      child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
    }
}
