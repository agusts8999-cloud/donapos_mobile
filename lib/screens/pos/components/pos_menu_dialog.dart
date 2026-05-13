import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class PosMenuDialog extends StatelessWidget {
  final bool isAdmin;

  const PosMenuDialog({
    super.key,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: 'POS MAIN MENU',
      icon: Icons.apps,
      width: 650.sc,
      height: 520.sc,
      content: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 16.sc,
        mainAxisSpacing: 16.sc,
        padding: EdgeInsets.all(8.sc),
        children: [
          _menuItem(context, Icons.history, 'RIWAYAT TRANSAKSI', Colors.purple, 'history'),
          _menuItem(context, Icons.money_off, 'BIAYA/PENGELUARAN', Colors.orange, 'expenses'),
          _menuItem(context, Icons.how_to_reg, 'ABSENSI', Colors.indigo, 'attendance'),
          _menuItem(context, Icons.print, 'PRINTER LABEL', Colors.indigo, 'label_printer'),
          _menuItem(context, Icons.settings, 'PRINTER KASIR', Colors.grey, 'settings'),
          _menuItem(context, Icons.restaurant, 'PRINTER DAPUR', Colors.deepOrange, 'kitchen_settings'),
          _menuItem(context, Icons.summarize, 'LAPORAN', Colors.blue, 'report'),
          _menuItem(context, Icons.manage_search, 'CEK DATA LOKAL', Colors.brown, 'check_local'),
          _menuItem(context, Icons.storage_rounded, 'CEK KAPASITAS', Colors.deepPurple, 'check_storage'),
          _menuItem(context, Icons.sync, 'SINKRONISASI', Colors.green, 'sync'),
          _menuItem(context, Icons.sd_storage, 'BACKUP', Colors.teal, 'backup'),
          if (isAdmin)
             _menuItem(context, Icons.admin_panel_settings, 'MENU ADMIN', Colors.blueGrey, 'admin'),
          _menuItem(context, Icons.logout, 'KELUAR KASIR', Colors.red, 'logout'),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, Color color, String command) {
    return InkWell(
      onTap: () => Navigator.pop(context, command),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          border: Border.all(color: color.withOpacity(0.3), width: 1.sc),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40.sc),
            SizedBox(height: 12.sc),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.sc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
