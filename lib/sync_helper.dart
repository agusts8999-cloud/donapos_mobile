import 'package:donapos_mobile/design_system.dart';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/widgets/sync_progress_dialog.dart';
import 'package:donapos_mobile/utils_ui.dart';

class SyncHelper {
  // Shared logic for running sync tasks with consistent UI feedback
  static Future<void> runSyncTask(
      BuildContext context, 
      String title, 
      Future<dynamic> Function({Function(String)? onProgress}) task,
      {VoidCallback? onSuccess}
  ) async {
    // 1. Show Progress Dialog
    ValueNotifier<String> statusNotifier = ValueNotifier('MENYIAPKAN DATA...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<String>(
          valueListenable: statusNotifier,
          builder: (context, status, child) {
              return SyncProgressDialog(status: status);
          }
      )
    );

    try {
      // 2. Execute Task
      final result = await task(onProgress: (status) {
          statusNotifier.value = status;
      });
      
      // Close Progress Dialog
      if (context.mounted) Navigator.pop(context);

      // 3. Handle Result
      if (context.mounted) {
          String msg = '$title BERHASIL.\nDATA: $result ITEM DIPROSES.';
          bool isZeroWarning = false;
          bool isError = false;

          // Special Map handling for complex results (like sales sync)
          if (result is Map) {
              int count = result['count'] ?? 0;
              List<String> logs = (result['logs'] as List?)?.map((e) => e.toString()).toList() ?? [];
              
              if (logs.isNotEmpty && logs.any((l) => l.contains('Failed') || l.contains('Error') || l.contains('Rejected'))) {
                   _showDebugDialog(context, title, count, logs);
                   return;
              }
              msg = '$title BERHASIL MEMPROSES $count DATA.';
          } 
          // Integer handling for standard syncs
          else if (result is int) {
               if (result == 0 && (title.contains('PRODUK') || title.contains('FULL'))) {
                  msg += '\n\nPERINGATAN: TIDAK ADA DATA YANG DISINKRONKAN.\nPASTIKAN PENGATURAN SERVER DAN LOKASI SUDAH BENAR.';
                  isZeroWarning = true;
                  isError = true; // Treat as red warning
              }
          }

          showAppModal(context, title: isZeroWarning ? 'SYNC SELESAI (KOSONG)' : 'SYNC SUCCESS', message: msg, isError: isError);
          
          if (onSuccess != null) onSuccess();
      }
    } catch (e) {
      // Close Progress Dialog if still open (check mounted)
      if (context.mounted) {
          // If the dialog was popped already? 
          // Actually if error happens, dialog is still open. We must pop it.
          // Is there a robust way to know if dialog is open? 
          // We assume it is open because we awaited the task.
          Navigator.pop(context); 
          showAppModal(context, title: 'SYNC FAILED', message: 'GAGAL MENYINKRONKAN $title.\nERROR: $e', isError: true);
      }
    }
  }

  static void _showDebugDialog(BuildContext context, String title, int count, List<String> logs) {
      showDialog(context: context, builder: (_) => AlertDialog(
           title: Text('${title.toUpperCase()} SELESAI', style: const TextStyle(fontWeight: FontWeight.bold)),
           content: SizedBox(
               width: double.maxFinite,
               height: 300,
               child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       Text('$count Transaksi Berhasil.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                       const SizedBox(height: 8),
                       const Text('LOG DETAIL (DEBUG):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                       const Divider(),
                       Expanded(
                           child: ListView(
                               children: logs.map((l) => Padding(
                                   padding: const EdgeInsets.symmetric(vertical: 2),
                                   child: Text(l, style: TextStyle(fontSize: 10, fontFamily: 'Monospace', color: l.contains('Failed') || l.contains('Error') || l.contains('Rejected') ? Colors.red : Colors.black87))
                               )).toList()
                           )
                       )
                   ]
               )
           ),
           actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('TUTUP'))]
       ));
  }
}
