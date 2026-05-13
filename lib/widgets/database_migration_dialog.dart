import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';

class DatabaseMigrationDialog extends StatefulWidget {
  final int oldVersion;
  final int newVersion;

  const DatabaseMigrationDialog({
    super.key, 
    required this.oldVersion, 
    required this.newVersion
  });

  @override
  State<DatabaseMigrationDialog> createState() => _DatabaseMigrationDialogState();
}

class _DatabaseMigrationDialogState extends State<DatabaseMigrationDialog> {
  bool _isProcessing = false;
  bool _isFinished = false;
  bool _isError = false;
  final List<String> _logs = [];

  void _addLog(String msg) {
    if (mounted) {
      setState(() {
        _logs.add("[${DateTime.now().toString().split(' ').last.substring(0, 8)}] $msg");
      });
    }
  }

  Future<void> _handleMigration() async {
    setState(() {
      _isProcessing = true;
      _logs.clear();
    });
    _addLog("Memulai Migrasi: v${widget.oldVersion} -> v${widget.newVersion}...");

    try {
      // Accessing database will trigger onUpgrade
      await DatabaseHelper.instance.database;
      
      // Get internal logs from DatabaseHelper
      _logs.addAll(DatabaseHelper.instance.migrationLogs);
      
      _addLog("MIGRASI SELESAI DENGAN SUKSES.");
      setState(() {
        _isFinished = true;
        _isError = false;
      });
    } catch (e) {
      _addLog("MIGRASI GAGAL: $e");
      _logs.addAll(DatabaseHelper.instance.migrationLogs);
      setState(() {
        _isFinished = true;
        _isError = true;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleReset() async {
    setState(() {
      _isProcessing = true;
      _logs.clear();
    });
    _addLog("MENGHAPUS DATABASE LAMA...");

    try {
      await DatabaseHelper.instance.resetDatabase();
      _addLog("DATABASE BERHASIL DIRESET.");
      
      _addLog("MENGINISIALISASI DATABASE BARU...");
      await DatabaseHelper.instance.database;
      _addLog("DATABASE BARU SIAP DIGUNAKAN.");
      
      setState(() {
        _isFinished = true;
        _isError = false;
      });
    } catch (e) {
      _addLog("GAGAL RESET DATABASE: $e");
      setState(() {
        _isFinished = true;
        _isError = true;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: MetroColors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: MetroColors.primary, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.storage, color: MetroColors.primary, size: 28),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      "PEMBARUAN DATABASE",
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w900, 
                        color: MetroColors.primary,
                        letterSpacing: 1
                      )
                    ),
                  ),
                  if (!_isProcessing)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black38, size: 22),
                      onPressed: () => Navigator.pop(context, false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const Divider(height: 32, thickness: 1, color: Colors.black12),
              
              if (!_isProcessing && !_isFinished) ...[
                Text(
                  "Ditemukan database versi lama (v${widget.oldVersion}). Aplikasi memerlukan versi v${widget.newVersion}.",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Pilih metode pembaruan:",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _handleReset,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: MetroColors.error),
                          padding: const EdgeInsets.all(16),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
                        ),
                        child: const Column(
                          children: [
                            Text("HAPUS BERSIH", style: TextStyle(color: MetroColors.error, fontWeight: FontWeight.w900)),
                            Text("(Data transaki & produk hilang)", style: TextStyle(fontSize: 9, color: MetroColors.error)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleMigration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetroColors.primary,
                          padding: const EdgeInsets.all(16),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
                        ),
                        child: const Column(
                          children: [
                            Text("MIGRASI DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                            Text("(Pertahankan data transaksi)", style: TextStyle(fontSize: 9, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("NANTI SAJA", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],

              if (_isProcessing || _isFinished) ...[
                const Text("DEBUG LOGS:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black38)),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  color: Colors.black.withOpacity(0.05),
                  padding: const EdgeInsets.all(8),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color dotColor = Colors.blue;
                      if (log.contains("SUCCESS") || log.contains("successful")) dotColor = Colors.green;
                      if (log.contains("FAILED") || log.contains("GAGAL")) dotColor = Colors.red;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("• ", style: TextStyle(color: dotColor, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(log, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                if (_isFinished)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, !_isError),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isError ? MetroColors.error : MetroColors.success,
                      padding: const EdgeInsets.all(16),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
                    ),
                    child: Text(
                      _isError ? "TUTUP & COBA LAGI" : "LANJUTKAN", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)
                    ),
                  ),
                if (_isProcessing)
                  const Center(child: CircularProgressIndicator(color: MetroColors.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
