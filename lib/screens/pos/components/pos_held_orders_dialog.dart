import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class PosHeldOrdersDialog extends StatelessWidget {
  final List<Map<String, dynamic>> heldOrders;
  final List<ResTable> tables;
  final Function(Map<String, dynamic>) onOrderSelected;

  const PosHeldOrdersDialog({
    super.key,
    required this.heldOrders,
    required this.tables,
    required this.onOrderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
        title: 'DAFTAR PESANAN HOLD',
        icon: Icons.list_alt,
        width: 800.sc,
        height: 600.sc,
        content: heldOrders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64.sc, color: Colors.white.withOpacity(0.05)),
                    SizedBox(height: 16.sc),
                    Text('TIDAK ADA PESANAN YANG DI-HOLD', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2.sc, fontSize: 12.sp)),
                  ],
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.all(16.sc),
                itemCount: heldOrders.length,
                separatorBuilder: (_, __) => SizedBox(height: 12.sc),
                itemBuilder: (ctx, i) {
                  final order = heldOrders[i];
                  final date = DateTime.parse(order['created_at']);
                  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
                  
                  String tableInfo = 'PROSES';
                  if (order['res_table_id'] != null) {
                      final table = tables.firstWhere((t) => t.id == order['res_table_id'], orElse: () => ResTable(id: 0, businessId: 0, locationId: 0, name: 'MEJA ?'));
                      tableInfo = 'MEJA ${table.name}${order['pax'] != null && order['pax'] > 0 ? ' (${order['pax']} P)' : ''}';
                  }

                  return Container(
                    padding: EdgeInsets.all(20.sc),
                    decoration: BoxDecoration(
                       color: Colors.grey[100],
                       borderRadius: BorderRadius.zero,
                       border: Border.all(color: Colors.black12, width: 1.sc)
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${order['sale_type']?.toUpperCase() ?? 'POS'} - $tableInfo', 
                                style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 1.sc)),
                              if (order['hold_note'] != null && order['hold_note'].isNotEmpty) ...[
                                SizedBox(height: 4.sc),
                                Text('NOTE: ${order['hold_note']}', 
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12.sp)),
                              ],
                              SizedBox(height: 6.sc),
                              if (order['customer_name'] != null && order['customer_name'] != 'Umum')
                                Padding(
                                  padding: EdgeInsets.only(bottom: 4.sc),
                                  child: Text('PELANGGAN: ${order['customer_name'].toUpperCase()}', 
                                    style: TextStyle(color: Colors.black87, fontSize: 10.sp, fontWeight: FontWeight.w900)),
                                ),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12.sc, color: Colors.black38),
                                  SizedBox(width: 6.sc),
                                  Text(DateFormat('dd/MM/yyyy HH:mm').format(date), 
                                    style: TextStyle(color: Colors.black45, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(currency.format(order['total']), 
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18.sp)),
                            SizedBox(height: 12.sc),
                            SizedBox(
                              width: 140.sc,
                              height: 48.sc,
                              child: MetroButton(
                                label: 'LANJUTKAN',
                                color: MetroColors.primary,
                                onPressed: () {
                                  Navigator.pop(context);
                                  onOrderSelected(order);
                                },
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
