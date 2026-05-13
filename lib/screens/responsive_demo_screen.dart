import 'package:flutter/material.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:donapos_mobile/design_system.dart';

class ResponsiveDemoScreen extends StatefulWidget {
  const ResponsiveDemoScreen({super.key});

  @override
  State<ResponsiveDemoScreen> createState() => _ResponsiveDemoScreenState();
}

class _ResponsiveDemoScreenState extends State<ResponsiveDemoScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inisialisasi scaler satu kali per screen
    ScreenScaler.init(context);
    // Load setting manual jika perlu (biasanya sudah di splash)
    ScreenScaler.loadSettings().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.sc), // AppBar height scaled
        child: AppBar(
          backgroundColor: MetroColors.primary,
          title: Text(
            'DEMO SISTEM SCALING POS (1340x800 BASE)',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sc),
              onPressed: _showScalingSettings,
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          // 1. SIDEBAR RESPONSIVE
          _buildSidebar(),
          
          // 2. MAIN CONTENT AREA
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24.sc), // Padding scaled
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 24.sc),
                  Expanded(child: _buildProductGrid()),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSampleDialog,
        backgroundColor: MetroColors.primary,
        icon: Icon(Icons.add, size: 24.sc),
        label: Text('TEST DIALOG', style: TextStyle(fontSize: 14.sp)),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250.sc, // Sidebar width scaled
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.sc),
            height: 150.sc,
            color: MetroColors.primary.withOpacity(0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30.sc,
                  backgroundColor: MetroColors.primary,
                  child: Icon(Icons.person, size: 30.sc, color: Colors.white),
                ),
                SizedBox(height: 10.sc),
                Text('KASIR DEMO', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 10.sc),
              children: [
                _sidebarItem(Icons.dashboard, 'DASHBOARD', true),
                _sidebarItem(Icons.shopping_cart, 'TRANSAKSI', false),
                _sidebarItem(Icons.inventory, 'PRODUK', false),
                _sidebarItem(Icons.analytics, 'LAPORAN', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, bool active) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 10.sc, vertical: 5.sc),
      decoration: BoxDecoration(
        color: active ? MetroColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8.sc),
      ),
      child: ListTile(
        leading: Icon(icon, color: active ? Colors.white : Colors.black54, size: 22.sc),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontSize: 14.sp,
            fontWeight: active ? FontWeight.bold : FontWeight.normal
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DAFTAR PRODUK RESPONSIVE',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900),
            ),
            Text(
              'Skala saat ini: ${ScreenScaler.scaleFactor.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12.sp, color: Colors.black45),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: Icon(Icons.print, size: 20.sc),
          label: Text('CETAK STRUK', style: TextStyle(fontSize: 14.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: MetroColors.primary,
            padding: EdgeInsets.symmetric(horizontal: 20.sc, vertical: 15.sc),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.sc)),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      itemCount: 8,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 20.sc,
        mainAxisSpacing: 20.sc,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        return Card(
          elevation: 4.sc,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.sc)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[50],
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15.sc)),
                  ),
                  child: Center(child: Icon(Icons.image, size: 50.sc, color: Colors.grey)),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.sc),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRODUK #${index + 1}', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5.sc),
                    Text('Rp 25.000', style: TextStyle(fontSize: 14.sp, color: MetroColors.primary, fontWeight: FontWeight.w900)),
                    SizedBox(height: 10.sc),
                    SizedBox(
                      width: double.infinity,
                      height: 40.sc,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                           backgroundColor: MetroColors.primary,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.sc))
                        ),
                        child: Text('TAMBAH', style: TextStyle(fontSize: 12.sp, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSampleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.sc)),
        titlePadding: EdgeInsets.all(24.sc),
        contentPadding: EdgeInsets.symmetric(horizontal: 24.sc),
        actionsPadding: EdgeInsets.all(16.sc),
        title: Text('DIALOG RESPONSIVE', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
        content: Container(
          width: 400.sc,
          child: Text(
            'Dialog ini akan menyesuaikan ukurannya secara proporsional sesuai scale factor device Anda.',
            style: TextStyle(fontSize: 16.sp, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('TUTUP', style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: MetroColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 20.sc, vertical: 10.sc),
            ),
            child: Text('MENGERTI', style: TextStyle(fontSize: 14.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showScalingSettings() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30.sc))),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(30.sc),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PENGATURAN SKALA TAMPILAN', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 20.sc),
            _buildScaleOption('Auto Scale (Rekomendasi)', !ScreenScaler.isManual, () {
              ScreenScaler.updateScaling(isManual: false).then((_) {
                Navigator.pop(context);
                setState(() {});
              });
            }),
            _buildScaleOption('Manual 100%', ScreenScaler.isManual && ScreenScaler.manualScaleValue == 1.0, () {
              ScreenScaler.updateScaling(isManual: true, manualScale: 1.0).then((_) {
                Navigator.pop(context);
                setState(() {});
              });
            }),
             _buildScaleOption('Manual 125%', ScreenScaler.isManual && ScreenScaler.manualScaleValue == 1.25, () {
              ScreenScaler.updateScaling(isManual: true, manualScale: 1.25).then((_) {
                Navigator.pop(context);
                setState(() {});
              });
            }),
             _buildScaleOption('Manual 150%', ScreenScaler.isManual && ScreenScaler.manualScaleValue == 1.5, () {
              ScreenScaler.updateScaling(isManual: true, manualScale: 1.5).then((_) {
                Navigator.pop(context);
                setState(() {});
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildScaleOption(String label, bool active, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: TextStyle(fontSize: 16.sp)),
      trailing: active ? Icon(Icons.check_circle, color: MetroColors.primary, size: 24.sc) : null,
    );
  }
}
