import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/icod_printer.dart';

class PrinterSettingsDialog extends StatefulWidget {
  const PrinterSettingsDialog({super.key});

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  BlueThermalPrinter printerBT = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  
  // Kasir Printer
  BluetoothDevice? _selectedDevice;
  String _printerType = 'bluetooth'; // 'bluetooth' or 'icod'
  bool _connected = false;
  
  String _icodConnType = 'USB'; // 'USB', 'Serial'
  String _icodSerialPath = '/dev/ttyS1';
  int _icodBaudRate = 115200;
  
  bool _isLoading = false;
  int _fontType = 1; // 0: Standard, 1: Condensed, 2: Condensed DH (Default)
  String _kitchenAddress = '';

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _printerType = prefs.getString('printer_settings_type') ?? 'bluetooth';
      _icodConnType = prefs.getString('icod_conn_type') ?? 'USB';
      _icodSerialPath = prefs.getString('icod_serial_path') ?? '/dev/ttyS1';
      _icodBaudRate = prefs.getInt('icod_baud_rate') ?? 115200;
      _fontType = prefs.getInt('printer_font_type') ?? 1;
      _kitchenAddress = prefs.getString('kitchen_printer_address') ?? '';

      try {
         _devices = await printerBT.getBondedDevices();
         final filter = prefs.getString('printer_filter_cashier_name') ?? 'RPP02N';
         if (filter.isNotEmpty) {
             _devices = _devices.where((d) => (d.name ?? '').toLowerCase().contains(filter.toLowerCase())).toList();
         }
      } catch (_) {}
      
      // Init Kasir
      if (_printerType == 'bluetooth') {
        final savedAddress = prefs.getString('printer_address');
        if (savedAddress != null && _devices.isNotEmpty) {
          final found = _devices.where((d) => d.address == savedAddress);
          if (found.isNotEmpty) {
            _selectedDevice = found.first;
            try {
              _connected = await printerBT.isDeviceConnected(_selectedDevice!) ?? false;
            } catch (_) {}
          }
        }
      } else {
        _connected = await IcodPrinter.isConnected();
      }

    } catch (e) {
      print("[Printer] Error init: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectPrinter() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    try {
        if (_printerType == 'bluetooth') {
          if (_selectedDevice != null) {
            if (await printerBT.isConnected ?? false) await printerBT.disconnect();
            await printerBT.connect(_selectedDevice!);
            await prefs.setString('printer_address', _selectedDevice!.address ?? '');
            if (mounted) setState(() => _connected = true);
          }
        } else {
          bool success = false;
          if (_icodConnType == 'USB') {
            success = await IcodPrinter.connectUsb();
          } else if (_icodConnType == 'Serial') {
            success = await IcodPrinter.connectSerial(_icodSerialPath, _icodBaudRate);
          }
          if (success) {
            await prefs.setString('icod_conn_type', _icodConnType);
            await prefs.setString('icod_serial_path', _icodSerialPath);
            await prefs.setInt('icod_baud_rate', _icodBaudRate);
            if (mounted) setState(() => _connected = true);
          }
        }
        await prefs.setString('printer_settings_type', _printerType);
    } catch (e) {
      print("Connect Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
        if (_printerType == 'bluetooth') {
          await printerBT.disconnect();
        } else {
          await IcodPrinter.disconnect();
        }
        if (mounted) setState(() => _connected = false);
    } catch (e) {
      print("Disconnect Error: $e");
    }
  }

  Future<void> _testPrint() async {
    setState(() => _isLoading = true);
    try {
        final prefs = await SharedPreferences.getInstance();
        if (_printerType == 'bluetooth') {
            if (_selectedDevice == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PILIH PRINTER KASIR TERLEBIH DAHULU!'), backgroundColor: Colors.red));
                return;
            }
            
            // Force reconnect to cashier printer for testing
            if (await printerBT.isConnected ?? false) await printerBT.disconnect();
            await printerBT.connect(_selectedDevice!);
            setState(() => _connected = true);
            
            final esc = 0x1B;
            List<int> fontCmd = [esc, 0x21, 0x00];
            if (_fontType == 1) fontCmd = [esc, 0x21, 0x01];
            if (_fontType == 2) fontCmd = [esc, 0x21, 0x01 | 0x10];

            await printerBT.writeBytes(Uint8List.fromList(fontCmd));
            printerBT.printCustom("DonaPOS CASHIER TEST", 0, 1);
            printerBT.printCustom("Printer Kasir Berhasil", 0, 1);
            printerBT.printNewLine();
            printerBT.printNewLine();
            await printerBT.paperCut();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test Print Kasir Terkirim')));
        } else {
            // iCod logic
            bool ok = await IcodPrinter.isConnected();
            if (!ok) await _connectPrinter();
            
            final esc = 0x1B;
            List<int> fontCmd = [esc, 0x21, 0x00];
            if (_fontType == 1) fontCmd = [esc, 0x21, 0x01];
            
            await IcodPrinter.printRaw(Uint8List.fromList(fontCmd));
            await IcodPrinter.printText("DonaPOS iCod TEST\nPrinter Berhasil\n\n\n\n");
            await IcodPrinter.cutPaper();
        }
    } catch (e) {
        debugPrint("Test Print Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
        title: 'PENGATURAN PRINTER KASIR',
        icon: Icons.print,
        width: 500,
        height: 600,
        content: Column(
            children: [
                Expanded(child: _buildKasirTab()),
            ],
          ),
    );
  }

  Widget _buildKasirTab() {
     return Column(
        children: [
            const Align(alignment: Alignment.centerLeft, child: Text("JENIS PRINTER KASIR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: MetroColors.text))),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeOption("BLUETOOTH", 'bluetooth'),
                const SizedBox(width: 8),
                _buildTypeOption("ICOD PRINTER", 'icod'),
              ],
            ),
            const SizedBox(height: 16),
            if (_printerType == 'bluetooth') ...[
              Expanded(child: _buildBluetoothDeviceList()),
            ] else ...[
              Expanded(child: _buildIcodSettings()),
            ],
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text("JENIS FONT STRUK", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: MetroColors.text))),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildFontOption("STANDAR", 0),
                _buildFontOption("PADAT", 1),
                _buildFontOption("TINGGI", 2),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusPanel(),
        ],
     );
  }

  Widget _buildBluetoothDeviceList() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
      child: _isLoading && _devices.isEmpty
         ? const Center(child: DonaposLoader(size: 80))
         : _devices.isEmpty 
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Tidak ada perangkat Bluetooth.', style: TextStyle(color: Colors.grey)),
                TextButton(onPressed: _initSettings, child: const Text("REFRESH"))
              ]))
            : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _devices.length,
              itemBuilder: (c, i) {
                  final d = _devices[i];
                  final isSelected = _selectedDevice?.address == d.address;
                   return Container(
                       margin: const EdgeInsets.only(bottom: 8),
                       decoration: BoxDecoration(
                         color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                         border: isSelected ? Border.all(color: Colors.green, width: 2) : Border(bottom: BorderSide(color: Colors.grey.shade200)),
                         borderRadius: isSelected ? BorderRadius.circular(8) : null,
                       ),
                       child: ListTile(
                           leading: Icon(Icons.print, color: isSelected ? Colors.green : Colors.grey),
                           title: Row(
                             children: [
                               Text(d.name ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                               if (isSelected) ...[
                                 const SizedBox(width: 8),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                   decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                   child: const Text("CASHIER ROLE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                 ),
                               ],
                               if (d.address == _kitchenAddress) ...[
                                 const SizedBox(width: 4),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                   decoration: BoxDecoration(color: Colors.deepOrange.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                                   child: const Text("KITCHEN ROLE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                 ),
                               ]
                             ],
                           ),
                           subtitle: Text(d.address ?? '', style: const TextStyle(fontSize: 11)),
                           trailing: isSelected && _connected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                           onTap: () async {
                               setState(() { _selectedDevice = d; });
                               await _connectPrinter();
                           },
                       ),
                   );
              },
            ),
    );
  }

  Widget _buildIcodSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text("METODE KONEKSI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
           const SizedBox(height: 8),
           DropdownButtonFormField<String>(
             value: _icodConnType,
             decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.zero), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
             items: ['USB', 'Serial'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
             onChanged: (v) => setState(() => _icodConnType = v!),
           ),
           if (_icodConnType == 'Serial') ...[
             const SizedBox(height: 16),
             const Text("SERIAL PATH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
             const SizedBox(height: 8),
             TextFormField(
               initialValue: _icodSerialPath,
               decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.zero)),
               onChanged: (v) => _icodSerialPath = v,
             ),
             const SizedBox(height: 16),
             const Text("BAUD RATE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
             const SizedBox(height: 8),
             DropdownButtonFormField<int>(
               value: _icodBaudRate,
               decoration: const InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.zero), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
               items: [9600, 19200, 38400, 57600, 115200].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
               onChanged: (v) => setState(() => _icodBaudRate = v!),
             ),
           ]
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: _connected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), border: Border.all(color: _connected ? Colors.green : Colors.red)),
            child: Center(child: Text(_connected ? 'TERHUBUNG' : 'TERPUTUS', style: TextStyle(color: _connected ? Colors.green : Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
          ),
        ),
        const SizedBox(width: 12),
        if (_connected) Expanded(child: MetroButton(label: 'TEST PRINT', icon: Icons.receipt, color: MetroColors.primary, onPressed: _testPrint))
        else Expanded(child: MetroButton(label: 'SAMBUNGKAN', icon: Icons.link, color: MetroColors.primary, onPressed: _connectPrinter, isLoading: _isLoading)),
        if (_connected) ...[
            const SizedBox(width: 12),
            Expanded(child: MetroButton(label: 'PUTUSKAN', icon: Icons.link_off, color: MetroColors.error, onPressed: _disconnectPrinter, isSecondary: true))
        ]
      ],
    );
  }

  Widget _buildTypeOption(String label, String type) {
    bool isSelected = _printerType == type;
    return GestureDetector(
      onTap: () { setState(() { _printerType = type; _connected = false; }); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? MetroColors.primary : Colors.transparent),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildFontOption(String label, int val) {
    bool selected = _fontType == val;
    return Expanded(
      child: InkWell(
        onTap: () async {
          setState(() => _fontType = val);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('printer_font_type', _fontType);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? MetroColors.primary : Colors.grey[100], border: Border.all(color: selected ? MetroColors.primary : Colors.grey[300]!)),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center),
        )
      )
    );
  }
}
