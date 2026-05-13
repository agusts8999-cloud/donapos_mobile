import 'package:flutter/material.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:intl/intl.dart';

class LocalDataCheckDialog extends StatefulWidget {
  const LocalDataCheckDialog({super.key});

  @override
  State<LocalDataCheckDialog> createState() => _LocalDataCheckDialogState();
}

class _LocalDataCheckDialogState extends State<LocalDataCheckDialog> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchData(); // Auto fetch today
  }

  Future<void> _fetchData() async {
    print("LocalDataCheck: Fetching data...");
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final start = DateFormat('yyyy-MM-dd').format(_startDate);
      final end = DateFormat('yyyy-MM-dd').format(_endDate);
      print("LocalDataCheck: Range $start to $end");
      
      final count = await DatabaseHelper.instance.getTotalTransactionCount();
      print("LocalDataCheck: TOTAL DB RECORDS: $count");
      
      if (count > 0) {
          final db = await DatabaseHelper.instance.database;
          final sample = await db.query('transactions', limit: 1);
          if (sample.isNotEmpty) {
             print("LocalDataCheck: Sample Date Format: ${sample.first['created_at']}");
          }
      }
      
      final data = await DatabaseHelper.instance.getTransactionsByDateRange(start, end);
      print("LocalDataCheck: Got ${data.length} transactions for range");

      if (mounted) {
        setState(() {
          _transactions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("LocalDataCheck: Error $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: MetroDesign.theme.copyWith(
            colorScheme: const ColorScheme.light(primary: MetroColors.primary),
          ),
          child: child!,
        );
      }
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) _startDate = _endDate;
        }
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _transactions.length;
    int syncedCount = _transactions.where((t) => (t['synced'] as int) == 1).length;
    int pendingCount = totalCount - syncedCount;

    return GlassDialog(
      title: 'CEK DATA LOKAL',
      icon: Icons.manage_search,
      width: 700,
      height: 600,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DARI TANGGAL', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: MetroColors.primary),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.black12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SAMPAI TANGGAL', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: MetroColors.primary),
                              const SizedBox(width: 8),
                              Text(DateFormat('dd MMM yyyy').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: MetroButton(
                    label: 'REFRESH',
                    icon: Icons.refresh,
                    onPressed: _fetchData,
                    isSecondary: true,
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Summary Section
          Row(
            children: [
              _buildSummaryCard('TOTAL DATA', totalCount.toString(), Colors.blue),
              const SizedBox(width: 12),
              _buildSummaryCard('SUDAH POSTING', syncedCount.toString(), MetroColors.retailPrimary),
              const SizedBox(width: 12),
              _buildSummaryCard('BELUM POSTING', pendingCount.toString(), MetroColors.error),
            ],
          ),
          const SizedBox(height: 16),

          // List Section
          Expanded(
            child: _isLoading 
              ? const Center(child: DonaposLoader(size: 80))
              : _transactions.isEmpty
                ? const Center(child: Text('TIDAK ADA DATA PADA RENTANG TANGGAL INI', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold)))
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: MetroColors.background,
                          child: const Row(
                            children: [
                              Expanded(flex: 2, child: Text('TANGGAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                              Expanded(flex: 2, child: Text('NO INVOICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                              Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                              Expanded(flex: 2, child: Text('PAYMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                              Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _transactions.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final date = DateTime.parse(tx['created_at']);
                              final isSynced = (tx['synced'] as int) == 1;

                                return InkWell(
                                  onTap: () => _showTransactionDetails(tx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    color: index % 2 == 0 ? Colors.white : Colors.grey[50], // Zebra striping
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(DateFormat('dd/MM HH:mm').format(date), style: const TextStyle(fontSize: 11))),
                                        Expanded(flex: 2, child: Text('#${tx['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                        Expanded(flex: 2, child: Text(currencyFormatter.format(tx['total']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                        Expanded(flex: 2, child: Text((tx['payment_method'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 10))),
                                        Expanded(flex: 2, child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: isSynced ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          child: Text(
                                            isSynced ? 'POSTED' : 'PENDING',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: isSynced ? Colors.green : Colors.red,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                        )),
                                      ],
                                    ),
                                  ),
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          
          const SizedBox(height: 16),
          MetroButton(label: 'TUTUP', onPressed: () => Navigator.pop(context), color: Colors.grey),
        ],
      )
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransactionDetails(Map<String, dynamic> tx) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text("DETAIL TRANSAKSI #${tx['id']}", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getTransactionItems(tx['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: DonaposLoader(size: 60));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("Tidak ada item produk.");
              }
              
              final items = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     color: Colors.grey[100],
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("Tanggal: ${tx['created_at']}"),
                         Text("Kasir: ${tx['cashier_name'] ?? '-'}"),
                         Text("Pelanggan: ${tx['customer_name'] ?? '-'}"),
                         const Divider(),
                         Text("Subtotal: ${currencyFormatter.format(tx['subtotal'])}"),
                         Text("Diskon: ${currencyFormatter.format(tx['discount'] + (tx['manual_discount'] ?? 0))}"),
                         Text("Pajak: ${currencyFormatter.format(tx['tax'])}"),
                         Text("Total: ${currencyFormatter.format(tx['total'])}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 12),
                   const Text("ITEM PRODUK:", style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   ConstrainedBox(
                     constraints: const BoxConstraints(maxHeight: 300),
                     child: ListView.separated(
                       shrinkWrap: true,
                       itemCount: items.length,
                       separatorBuilder: (_, __) => const Divider(),
                       itemBuilder: (ctx, idx) {
                         final item = items[idx];
                         return ListTile(
                           contentPadding: EdgeInsets.zero,
                           title: FutureBuilder<Map<String, dynamic>?>(
                              future: DatabaseHelper.instance.getProductById(item['product_id']),
                              builder: (c, snap) => Text(snap.data?['name'] ?? 'Product #${item['product_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                           ),
                           subtitle: item['note'] != null && item['note'].isNotEmpty 
                              ? Text("Note: ${item['note']}", style: const TextStyle(fontSize: 10, color: Colors.grey)) 
                              : null,
                           trailing: Text("${item['qty']} x ${currencyFormatter.format(item['price'])}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                         );
                       },
                     ),
                   )
                ],
              );
            },
          ),
        ),
        actions: [
          if ((tx['synced'] as int) == 1)
             TextButton(
               onPressed: () async {
                   final confirm = await showDialog<bool>(
                       context: context,
                       builder: (c) => AlertDialog(
                          title: const Text('RESET POSTING?'),
                          content: const Text('Transaksi ini akan ditandai BELUM POSTING dan aplikasi akan mencoba mengupload ulang. Lakukan ini jika data tidak muncul di Web ERP.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('BATAL')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('YA, RESET')),
                          ],
                       )
                   );
                   
                   if (confirm == true) {
                       await DatabaseHelper.instance.markTransactionUnsynced(tx['id']);
                       if (mounted) Navigator.pop(ctx);
                       _fetchData(); // Refresh list to update status color
                       
                       if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status Reset! Silakan ke menu SINKRONISASI untuk upload ulang.')));
                       }
                   }
               },
               child: const Text("RESET POSTING STATUS", style: TextStyle(color: Colors.orange)),
             ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("TUTUP"),
          )
        ],
      )
    );
  }
}
