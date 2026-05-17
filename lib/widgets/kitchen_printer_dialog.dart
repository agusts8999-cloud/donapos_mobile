import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as bt;
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart' as p3;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart' as ep;
import 'dart:async';
import 'dart:typed_data';

class KitchenPrinterDialog extends StatefulWidget {
  const KitchenPrinterDialog({super.key});

  @override
  State<KitchenPrinterDialog> createState() => _KitchenPrinterDialogState();
}

class _KitchenPrinterDialogState extends State<KitchenPrinterDialog> {
  String _printerType = 'bluetooth'; // bluetooth, lan, usb
  String _printerAddress = '';
  String _cashierAddress = '';
  bool _isEnabled = false;
  
  // Bluetooth Specific
  bt.BlueThermalPrinter bluetooth = bt.BlueThermalPrinter.instance;
  List<bt.BluetoothDevice> _btDevices = [];
  
  // USB Specific (using thermal_printer for discovery if possible, or manual)
  // thermal_printer doesn't always have discovery for USB in all versions
  
  final _ipController = TextEditingController();
  final _aliasController = TextEditingController();
  bool _isLoading = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _scanBluetooth();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _printerType = prefs.getString('kitchen_printer_type') ?? 'bluetooth';
      _printerAddress = prefs.getString('kitchen_printer_address') ?? '';
      _cashierAddress = prefs.getString('printer_address') ?? '';
      _aliasController.text = prefs.getString('kitchen_printer_alias') ?? 'PRINTER DAPUR';
      _isEnabled = prefs.getBool('kitchen_printer_enabled') ?? false;
      if (_printerType == 'lan') {
        _ipController.text = _printerAddress;
      }
    });

    if (_printerType == 'bluetooth' && _printerAddress.isNotEmpty) {
        bool conn = await bluetooth.isConnected ?? false;
        setState(() => _connected = conn);
    }
  }

  Future<void> _saveSettings() async {
    final address = _printerType == 'lan' ? _ipController.text.trim() : _printerAddress.trim();
    if (_isEnabled && address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Isi alamat printer dapur (Bluetooth atau IP) sebelum mengaktifkan.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kitchen_printer_type', _printerType);
    await prefs.setString('kitchen_printer_address', address);
    await prefs.setString('kitchen_printer_alias', _aliasController.text);
    await prefs.setBool('kitchen_printer_enabled', _isEnabled);
    await prefs.setBool('show_kitchen_button', _isEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konfigurasi Printer Dapur Disimpan')));
      Navigator.pop(context);
    }
  }

  Future<void> _scanBluetooth() async {
    try {
      final devices = await bluetooth.getBondedDevices();
      setState(() {
        _btDevices = devices;
      });
    } catch (e) {
      print("BT Scan Error: $e");
    }
  }

  Future<void> _testPrint() async {
    setState(() => _isLoading = true);
    try {
        final profile = await ep.CapabilityProfile.load();
        final generator = ep.Generator(ep.PaperSize.mm58, profile);
        List<int> bytes = [];

        bytes += generator.reset();
        bytes += generator.text("DonaPOS KITCHEN TEST", styles: const ep.PosStyles(align: ep.PosAlign.center, bold: true));
        bytes += generator.text("Printer Dapur Berhasil!", styles: const ep.PosStyles(align: ep.PosAlign.center));
        bytes += generator.hr();
        bytes += generator.text("Tipe: ${_printerType.toUpperCase()}", styles: const ep.PosStyles(align: ep.PosAlign.center));
        bytes += generator.text("Alamat: ${_printerType == 'lan' ? _ipController.text : _printerAddress}", styles: const ep.PosStyles(align: ep.PosAlign.center));
        bytes += generator.feed(3);
        bytes += generator.cut();

        if (_printerType == 'bluetooth') {
            if (_printerAddress.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PILIH PRINTER TERLEBIH DAHULU!'), backgroundColor: Colors.red));
                 return;
            }
            // Force reconnect to kitchen printer for testing
            if (await bluetooth.isConnected ?? false) await bluetooth.disconnect();
            
            final devs = await bluetooth.getBondedDevices();
            final d = devs.firstWhere((element) => element.address == _printerAddress, orElse: () => throw "Printer Dapur tidak terdaftar di Paired Bluetooth");
            await bluetooth.connect(d);
            setState(() => _connected = true);

            await bluetooth.writeBytes(Uint8List.fromList(bytes));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test Print Dapur Terkirim (Bluetooth)')));
        } else if (_printerType == 'lan') {
            final ip = _ipController.text.trim();
            if (ip.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MASUKKAN IP PRINTER!'), backgroundColor: Colors.red));
                 return;
            }
            var manager = p3.PrinterManager.instance;
            bool res = await manager.connect(type: p3.PrinterType.network, model: p3.TcpPrinterInput(ipAddress: ip));
            if (res) {
                await manager.send(type: p3.PrinterType.network, bytes: bytes);
                await Future.delayed(const Duration(seconds: 1));
                await manager.disconnect(type: p3.PrinterType.network);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test Print Terkirim (LAN)')));
            } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GAGAL TERHUBUNG KE IP PRINTER'), backgroundColor: Colors.red));
            }
        }
    } catch (e) {
        debugPrint("Test Print Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
        if (_printerType == 'bluetooth') {
            await bluetooth.disconnect();
        }
        setState(() => _connected = false);
    } catch (e) {
        debugPrint("Disconnect Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: 'SETTING PRINTER DAPUR (KOT)',
      icon: Icons.restaurant,
      width: 600,
      height: 750,
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AKTIFKAN PRINTER DAPUR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 11)),
                    Text(_connected ? 'STATUS: TERHUBUNG' : 'STATUS: TERPUTUS', style: TextStyle(color: _connected ? Colors.green : Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                  activeColor: MetroColors.primary,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),
            const Text('NAMA ALIAS PRINTER (MISAL: DAPUR BELAKANG)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 9)),
            const SizedBox(height: 8),
            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Masukkan Nama Alias...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12)
              ),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('TIPE KONEKSI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 10)),
            const SizedBox(height: 12),
            Row(
              children: [
                _typeBtn('BLUETOOTH', Icons.bluetooth, 'bluetooth'),
                const SizedBox(width: 8),
                _typeBtn('LAN (E-NET)', Icons.lan, 'lan'),
                const SizedBox(width: 8),
                _typeBtn('USB', Icons.usb, 'usb'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 300, // Fixed height for scrollable list inside scrollable view
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
              ),
              child: _buildConfigUI(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: MetroButton(
                    label: 'TEST PRINT',
                    icon: Icons.print,
                    color: Colors.blueGrey,
                    onPressed: _testPrint,
                    isLoading: _isLoading,
                  ),
                ),
                const SizedBox(width: 8),
                if (_connected && _printerType == 'bluetooth') ...[
                   Expanded(
                      child: MetroButton(
                          label: 'PUTUSKAN',
                          icon: Icons.link_off,
                          color: Colors.redAccent,
                          onPressed: _disconnectPrinter,
                          isSecondary: true,
                      ),
                   ),
                   const SizedBox(width: 8),
                ],
                Expanded(
                  child: MetroButton(
                    label: 'SIMPAN',
                    icon: Icons.save,
                    color: MetroColors.primary,
                    onPressed: _saveSettings,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String label, IconData icon, String type) {
    final isSelected = _printerType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _printerType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? MetroColors.primary : Colors.black.withOpacity(0.05),
            border: isSelected ? null : Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black45, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black45, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigUI() {
    if (_printerType == 'bluetooth') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daftar Printer Paired:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              IconButton(onPressed: _scanBluetooth, icon: const Icon(Icons.refresh, size: 18)),
            ],
          ),
          Expanded(
            child: _btDevices.isEmpty
                ? const Center(child: Text('Tidak ada perangkat Bluetooth paired'))
                : ListView.builder(
                    itemCount: _btDevices.length,
                    itemBuilder: (context, i) {
                      final d = _btDevices[i];
                      final isSelected = _printerAddress == d.address;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.deepOrange.withOpacity(0.1) : Colors.transparent,
                          border: isSelected ? Border.all(color: Colors.deepOrange, width: 2) : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                          borderRadius: isSelected ? BorderRadius.circular(8) : null,
                        ),
                        child: ListTile(
                          leading: Icon(Icons.restaurant, color: isSelected ? Colors.deepOrange : Colors.grey),
                          title: Row(
                            children: [
                              Text(d.name ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(4)),
                                  child: const Text("KITCHEN ROLE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                              if (d.address == _cashierAddress) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                  child: const Text("CASHIER ROLE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ]
                            ],
                          ),
                          subtitle: Text(d.address ?? '', style: const TextStyle(fontSize: 11)),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.deepOrange) : null,
                          onTap: () => setState(() => _printerAddress = d.address ?? ''),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    } else if (_printerType == 'lan') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alamat IP Printer (contoh: 192.168.1.100):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '192.168.x.x',
              prefixIcon: Icon(Icons.settings_ethernet),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          const Text('Info: Pastikan tablet dan printer berada dalam satu jaringan Wifi/LAN yang sama.', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
        ],
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.usb, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Koneksi USB akan otomatis mendeteksi printer yang terhubung saat mencetak.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }
  }
}
