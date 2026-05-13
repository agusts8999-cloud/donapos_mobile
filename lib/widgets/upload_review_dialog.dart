import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:intl/intl.dart';

class UploadReviewDialog extends StatefulWidget {
  final Future<void> Function() onConfirmed;

  const UploadReviewDialog({super.key, required this.onConfirmed});

  @override
  State<UploadReviewDialog> createState() => _UploadReviewDialogState();
}

class _UploadReviewDialogState extends State<UploadReviewDialog> {
  List<Map<String, dynamic>> _unsynced = [];
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getUnsyncedTransactions();
    final total = await DatabaseHelper.instance.getTotalTransactionCount();
    setState(() {
      _unsynced = data;
      _totalCount = total;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: 'VERIFIKASI DATA UPLOAD',
      icon: Icons.fact_check,
      width: 800,
      height: 600,
      content: _isLoading
          ? const Center(child: DonaposLoader(size: 80))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: MetroColors.primary.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL TRANSAKSI DI HP: $_totalCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('SIAP UPLOAD: ${_unsynced.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MetroColors.accent)),
                      IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _loadData),
                    ],
                  ),
                ),
                Expanded(
                  child: _unsynced.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_done, size: 48, color: Colors.green),
                              const SizedBox(height: 16),
                              Text(
                                _totalCount > 0 ? 'SEMUA DATA SUDAH TERSINKRON' : 'BELUM ADA TRANSAKSI HARI INI',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                              ),
                              const SizedBox(height: 8),
                              const Text('TRANSAKSI STATUS "MEJA / HOLD" TIDAK AKAN MUNCUL DI SINI.', style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _unsynced.length,
                          itemBuilder: (context, index) {
                            final tx = _unsynced[index];
                            return _buildTransactionCard(tx);
                          },
                        ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _unsynced.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.onConfirmed();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetroColors.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text('UPLOAD SEKARANG',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: const RoundedRectangleBorder(side: BorderSide(color: Colors.black12)),
      child: ExpansionTile(
        subtitle: Text(
          'Total: ${NumberFormat('#,###').format(tx['total'])} | ${tx['payment_method']?.toUpperCase()}',
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        title: Text(
          'NOTA: ${tx['id']} | ${tx['created_at']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        leading: const CircleAvatar(
          backgroundColor: MetroColors.primary,
          child: Icon(Icons.receipt_long, color: Colors.white, size: 20),
        ),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getTransactionItems(tx['id']),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final items = snapshot.data!;
              return Column(
                children: [
                  const Divider(),
                  ...items.map((item) => ListTile(
                        dense: true,
                        title: Text('ITEM ID: ${item['product_id']}'),
                        subtitle: Text('Qty: ${item['qty']} x ${NumberFormat('#,###').format(item['price'])}'),
                        trailing: Text(NumberFormat('#,###').format(item['qty'] * item['price'])),
                      )),
                  const Divider(),
                  _buildDebugPayload(tx, items),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebugPayload(Map<String, dynamic> tx, List<Map<String, dynamic>> items) {
    // Generate a quick debug payload view
    final debugPayload = {
      'id_lokal': tx['id'],
      'tgl': tx['created_at'],
      'total': tx['total'],
      'item_count': items.length,
      'metode': tx['payment_method'],
    };

    return Container(
      width: double.infinity,
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VERIFIKASI DEBUG API:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9, color: Colors.orange)),
          const SizedBox(height: 4),
          Text(const JsonEncoder.withIndent('  ').convert(debugPayload),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black45)),
        ],
      ),
    );
  }
}
