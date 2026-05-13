import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/screens/pos/components/table_pax_dialog.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class PosTableSelectorDialog extends StatefulWidget {
  final List<ResTable> tables;
  final ResTable? selectedTable;
  final Function(ResTable, int) onTableSelected;
  final VoidCallback onSyncPressed;
  final VoidCallback onManualPressed;
  final VoidCallback onReleaseTable;

  const PosTableSelectorDialog({
    super.key,
    required this.tables,
    this.selectedTable,
    required this.onTableSelected,
    required this.onSyncPressed,
    required this.onManualPressed,
    required this.onReleaseTable,
  });

  @override
  State<PosTableSelectorDialog> createState() => _PosTableSelectorDialogState();
}

class _PosTableSelectorDialogState extends State<PosTableSelectorDialog> {
  ResTable? _tempSelectedTable;

  @override
  void initState() {
    super.initState();
    _tempSelectedTable = widget.selectedTable;
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
        title: 'PILIH MEJA RESTORAN',
        icon: Icons.table_restaurant,
        width: 900.sc,
        height: 750.sc,
        content: Column(
          children: [
              // TOP NAVIGATION / CHOICE
              Row(
                  children: [
                      Expanded(
                          child: InkWell(
                              onTap: widget.onSyncPressed,
                              child: Container(
                                  padding: EdgeInsets.all(16.sc),
                                  decoration: BoxDecoration(
                                      color: MetroColors.primary.withOpacity(0.1),
                                      border: Border.all(color: MetroColors.primary.withOpacity(0.3), width: 1.sc)
                                  ),
                                  child: Column(
                                      children: [
                                          Icon(Icons.cloud_download, color: MetroColors.primary, size: 28.sc),
                                          SizedBox(height: 8.sc),
                                          Text('SINKRON DARI SERVER', style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 11.sp, letterSpacing: 1.sc)),
                                          Text('AMBIL DATA DARI CLOUD', style: TextStyle(color: Colors.white24, fontSize: 8.sp, fontWeight: FontWeight.bold)),
                                      ],
                                  ),
                              ),
                          ),
                      ),
                      SizedBox(width: 12.sc),
                      Expanded(
                          child: InkWell(
                              onTap: widget.onManualPressed,
                              child: Container(
                                  padding: EdgeInsets.all(16.sc),
                                  decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      border: Border.all(color: Colors.purple.withOpacity(0.3), width: 1.sc)
                                  ),
                                  child: Column(
                                      children: [
                                          Icon(Icons.add_circle, color: Colors.purpleAccent, size: 28.sc),
                                          SizedBox(height: 8.sc),
                                          Text('INPUT MANUAL', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w900, fontSize: 11.sp, letterSpacing: 1.sc)),
                                          Text('TAMBAH MEJA LOKAL', style: TextStyle(color: Colors.white24, fontSize: 8.sp, fontWeight: FontWeight.bold)),
                                      ],
                                  ),
                              ),
                          ),
                      ),
                  ],
              ),
              SizedBox(height: 32.sc),
              Divider(color: Colors.white12, height: 1.sc, thickness: 1.sc),
              SizedBox(height: 32.sc),
              
              // TABLE LIST OR EMPTY STATE
              Expanded(
                  child: widget.tables.isEmpty 
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(Icons.table_bar, size: 64.sc, color: Colors.white.withOpacity(0.05)),
                                  SizedBox(height: 24.sc),
                                  Text('BELUM ADA DATA MEJA', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 2.sc, fontSize: 14.sp)),
                                  Text('SILAKAN PILIH SALAH SATU OPSI DI ATAS.', style: TextStyle(color: Colors.white10, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                              ],
                          ),
                      )
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4, 
                              childAspectRatio: 1.35,
                              crossAxisSpacing: 20.sc,
                              mainAxisSpacing: 20.sc
                          ),
                          itemCount: widget.tables.length,
                          itemBuilder: (ctx, i) {
                              final table = widget.tables[i];
                              final isSelected = _tempSelectedTable?.id == table.id;
                              return MetroTile(
                                label: table.name,
                                subLabel: isSelected ? 'TERPILIH' : (table.description ?? 'AVAILABLE'),
                                icon: isSelected ? Icons.check_circle : Icons.table_restaurant,
                                color: isSelected ? MetroColors.retailPrimary : Colors.grey.shade400,
                                onTap: () async {
                                    final pax = await showDialog<int>(
                                      context: context, 
                                      builder: (_) => TablePaxDialog(table: table)
                                    );
                                    
                                    if (pax != null) {
                                        setState(() {
                                            _tempSelectedTable = table;
                                        });
                                        widget.onTableSelected(table, pax);
                                    }
                                },
                              );
                          },
                      ),
              ),
          ],
        ),
         footer: _tempSelectedTable != null ? Container(
             padding: EdgeInsets.only(top: 16.sc),
             child: Row(
                 children: [
                     Expanded(
                         child: MetroButton(
                            label: 'LEPAS MEJA [ ${_tempSelectedTable!.name} ]',
                            color: MetroColors.error,
                            onPressed: widget.onReleaseTable,
                         ),
                     ),
                     SizedBox(width: 12.sc),
                     Expanded(
                         child: MetroButton(
                            label: 'TETAP GUNAKAN MEJA INI',
                            color: MetroColors.primary,
                            onPressed: () => Navigator.pop(context),
                         ),
                     ),
                 ],
             ),
         ) : null,
    );
  }
}
