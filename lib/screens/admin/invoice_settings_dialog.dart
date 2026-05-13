import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:donapos_mobile/widgets/logo_debug_dialog.dart';
import 'package:donapos_mobile/utils_print.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:donapos_mobile/config.dart';

class InvoiceSettingsDialog extends StatefulWidget {
  const InvoiceSettingsDialog({super.key});

  @override
  State<InvoiceSettingsDialog> createState() => _InvoiceSettingsDialogState();
}

class _InvoiceSettingsDialogState extends State<InvoiceSettingsDialog> {
  final _apiService = ApiService();
  bool _isLoading = false;
  Map<String, String> _info = {
    'name': 'DonaPOS',
    'address': '-',
    'mobile': '-',
    'lbl_subtotal': 'Subtotal',
    'lbl_discount': 'Diskon',
    'lbl_tax': 'Pajak',
    'lbl_total': 'Total',
    'lbl_return': 'Kembalian',
    'footer_text': '-',
    'invoice_prefix': 'INV'
  };
  String? _logoPath;
  int _logoKey = 0;
  bool _isLogoEnabled = true;
  int _paperSize = 58;
  bool _showAppVersion = true;
  String _appVersion = "";
  double _logoRatio = 0.66; // Default to 2/3
  final _prefixController = TextEditingController();
  final _startIndexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final pkg = await PackageInfo.fromPlatform();
    
    // Clear cache to ensure logo updates
    imageCache.clear();
    imageCache.clearLiveImages();
    
    setState(() {
      _appVersion = "${pkg.version}+${pkg.buildNumber}";
      _logoKey++; // Force rebuild
      _info = {
        'name': prefs.getString('business_name') ?? 'DonaPOS',
        'address': prefs.getString('business_address') ?? 'Indonesia',
        'mobile': prefs.getString('business_mobile') ?? '-',
        'lbl_subtotal': prefs.getString('lbl_subtotal') ?? 'Subtotal',
        'lbl_discount': prefs.getString('lbl_discount') ?? 'Diskon',
        'lbl_tax': prefs.getString('lbl_tax') ?? 'Pajak',
        'lbl_total': prefs.getString('lbl_total') ?? 'TOTAL',
        'lbl_return': prefs.getString('lbl_return') ?? 'Kembalian',
        'footer_text': prefs.getString('footer_text') ?? 'Terima Kasih',
        'invoice_prefix': prefs.getString('invoice_prefix') ?? 'MBL',
      };
      _logoPath = prefs.getString('logo_path');
      _isLogoEnabled = prefs.getBool('is_logo_enabled') ?? true;
      _paperSize = prefs.getInt('printer_paper_size') ?? 58;
      _logoRatio = prefs.getDouble('printer_logo_ratio') ?? 0.66;
      _showAppVersion = prefs.getBool('show_app_version') ?? true;

      _prefixController.text = _info['invoice_prefix'] ?? 'MBL';
      _startIndexController.text = (prefs.getInt('invoice_start_index') ?? 0).toString();
    });
  }

  Future<void> _saveNumberingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invoice_prefix', _prefixController.text.trim().toUpperCase());
    await prefs.setInt('invoice_start_index', int.tryParse(_startIndexController.text) ?? 0);
    
    setState(() {
       _info['invoice_prefix'] = _prefixController.text.trim().toUpperCase();
    });

    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PENGATURAN PENOMORAN DISIMPAN')));
    }
  }

  Future<void> _toggleLogo(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logo_enabled', val);
    setState(() => _isLogoEnabled = val);
  }

  Future<void> _toggleAppVersion(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_app_version', val);
    setState(() => _showAppVersion = val);
  }

  Future<void> _setPaperSize(int val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('printer_paper_size', val);
    setState(() => _paperSize = val);
    
    // Auto-optimize if logo exists
    if (_logoPath != null) {
      await _optimizeLogo();
    }
  }

  Future<void> _setLogoRatio(double val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('printer_logo_ratio', val);
    setState(() => _logoRatio = val);
  }

  Future<void> _optimizeLogo() async {
    if (_logoPath == null) return;
    
    setState(() => _isLoading = true);
    final String? optimizedPath = await PrintHelper.processAndSaveLogo(_logoPath!, _paperSize);
    
    if (optimizedPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logo_path', optimizedPath);
      setState(() {
        _logoPath = optimizedPath;
        _logoKey++;
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LOGO BERHASIL DIOPTIMASI UNTUK PRINTER')));
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _syncFromCloud() async {
    setState(() => _isLoading = true);
    await showAppModal(context, title: 'SYNC', message: 'MENGUNDUH PENGATURAN & LOGO DARI SERVER...');
    
    try {
      await _apiService.syncBusinessDetails();
      await _apiService.syncTaxes(); // Also useful
      await _loadSettings();
      
      if (!mounted) return;
      Navigator.pop(context); // Close modal
      showAppModal(context, title: 'BERHASIL', message: 'DATA FAKTUR & LOGO TELAH DIPERBARUI.');
    } catch (e) {
      Navigator.pop(context);
      showAppModal(context, title: 'GAGAL', message: 'TERJADI KESALAHAN: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _testPrint() async {
    final printer = BlueThermalPrinter.instance;
    if ((await printer.isConnected) != true) {
      showAppModal(context, title: 'PRINTER OFF', message: 'PASTIKAN PRINTER SUDAH TERHUBUNG DI MENU KASIR.', isError: true);
      return;
    }

    try {
        // 1. Reset Printer (ESC @) to ensure clean state
        await printer.writeBytes(Uint8List.fromList([27, 64]));
        await Future.delayed(const Duration(milliseconds: 500));

        // Logo - Only print if enabled
        bool logoPrinted = false;
        if (_isLogoEnabled && _logoPath != null && File(_logoPath!).existsSync()) {
            final Uint8List? imgBytes = await PrintHelper.generateImageBytes(_logoPath!, paperSize: _paperSize, ratio: _logoRatio);
            
            if (imgBytes != null) {
                await printer.writeBytes(imgBytes);
                logoPrinted = true;
                await Future.delayed(const Duration(milliseconds: 500));
            }
        }

        // Print Text Header if logo disabled OR logo failed to print
        if (!logoPrinted) {
          printer.printCustom(_info['name']!.toUpperCase(), 3, 1);
          printer.printCustom(_info['address']!, 1, 1);
          printer.printCustom(_info['mobile']!, 1, 1);
        }

        printer.printNewLine();

        printer.printCustom("----------------", 1, 1);
        printer.printCustom("TEST PRINT / PREVIEW", 2, 1);
        printer.printCustom("----------------", 1, 1);
        printer.printLeftRight("Item Test A", "15.000", 1);
        printer.printLeftRight("Item Test B", "20.000", 1);
        printer.printCustom("----------------", 1, 1);
        
        // Footer labels
        printer.printLeftRight(_info['lbl_subtotal']!, "35.000", 1);
        printer.printLeftRight(_info['lbl_total']!, "35.000", 2);
        
        printer.printCustom("----------------", 1, 1);
        printer.printNewLine();
        
        List<String> footers = _info['footer_text']!.split('\n');
        for(var line in footers) {
             if(line.trim().isNotEmpty) printer.printCustom(line.trim(), 1, 1);
        }

        if (_showAppVersion) {
          printer.printCustom("${AppConfig.appName} ${_appVersion}", 0, 1);
        }
        
        printer.printNewLine();
        printer.printNewLine();
        printer.printNewLine();
        printer.paperCut();
    } catch (e) {
        showAppModal(context, title: 'PRINT ERROR', message: '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return GlassDialog(
      title: 'PENGATURAN FAKTUR',
      icon: Icons.receipt_long,
      width: 900,
      height: 600,
      content: _isLoading 
        ? const Center(child: PowerfulLoader(message: 'MEMUAT DATA...'))
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PANEL: SETTINGS
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       MetroButton(
                         label: 'SYNC DARI CLOUD SEKARANG',
                         icon: Icons.cloud_download,
                         color: MetroColors.primary,
                         onPressed: _syncFromCloud,
                       ),
                       const SizedBox(height: 8),
                       const SizedBox(height: 8),
                       const Text('TEKAN TOMBOL DI ATAS UNTUK MENGAMBIL LOGO & FORMAT TERBARU DARI ERP.', style: TextStyle(fontSize: 10, color: Colors.black54)),
                       
                       const SizedBox(height: 24),
                       const Text('LAYOUT INFO (READ-ONLY)', style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary)),
                       const Divider(),
                        _buildInfoRow('Nama Bisnis', _info['name']),
                       _buildInfoRow('Alamat', _info['address']),
                       _buildInfoRow('Kontak', _info['mobile']),
                       
                       const SizedBox(height: 24),
                       const Text('PENGATURAN PENOMORAN', style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary)),
                       const Divider(),
                       const Text('MODIFIKASI PREFIX & NOMOR AWAL UNTUK MENGHINDARI DUPLIKASI DENGAN ERP.', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 12),
                       Row(
                         children: [
                           Expanded(
                             child: TextField(
                               controller: _prefixController,
                               decoration: const InputDecoration(
                                 labelText: 'PREFIX NO. FAKTUR',
                                 labelStyle: TextStyle(fontSize: 12),
                                 border: OutlineInputBorder(),
                                 isDense: true,
                               ),
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                             ),
                           ),
                           const SizedBox(width: 12),
                           Expanded(
                             child: TextField(
                               controller: _startIndexController,
                               keyboardType: TextInputType.number,
                               decoration: const InputDecoration(
                                 labelText: 'INDEX MULAI (START)',
                                 labelStyle: TextStyle(fontSize: 12),
                                 border: OutlineInputBorder(),
                                 isDense: true,
                               ),
                               style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 8),
                       SizedBox(
                         width: double.infinity,
                         child: ElevatedButton.icon(
                           onPressed: _saveNumberingSettings,
                           icon: const Icon(Icons.save, size: 16),
                           label: const Text('UPDATE PENOMORAN', style: TextStyle(fontSize: 11)),
                           style: ElevatedButton.styleFrom(backgroundColor: MetroColors.secondary),
                         ),
                       ),
                       
                       const SizedBox(height: 24),
                       const Text('LABEL STRUK', style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary)),
                       const Divider(),
                       _buildInfoRow('Subtotal Label', _info['lbl_subtotal']),
                       _buildInfoRow('Diskon Label', _info['lbl_discount']),
                       _buildInfoRow('Pajak Label', _info['lbl_tax']),
                       _buildInfoRow('Total Label', _info['lbl_total']),
                       
                       const SizedBox(height: 24),
                       const Text('FOOTER', style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary)),
                       Container(
                         width: double.infinity,
                         padding: const EdgeInsets.all(12),
                         color: Colors.grey.shade100,
                         child: Text(_info['footer_text'] ?? '-', style: const TextStyle(fontFamily: 'monospace')),
                       ),
                       const SizedBox(height: 32),
                       const Text('PENGATURAN CETAK', style: TextStyle(fontWeight: FontWeight.w900, color: MetroColors.primary)),
                       const Divider(),
                       SwitchListTile(
                           contentPadding: EdgeInsets.zero,
                           title: const Text('CETAK LOGO PADA STRUK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                           subtitle: const Text('MATIKAN JIKA PRINTER ANDA MENGELUARKAN KARAKTER ASING (ASCII) SAAT MENCETAK GAMBAR.', style: TextStyle(fontSize: 9)),
                           value: _isLogoEnabled, 
                           activeColor: MetroColors.primary,
                           onChanged: _toggleLogo,
                       ),
                       if (_isLogoEnabled) ...[
                         const SizedBox(height: 8),
                         const Text('PERBANDINGAN UKURAN LOGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildRatioOption('PENUH (100%)', 1.0),
                              _buildRatioOption('BESAR (2/3)', 0.66),
                              _buildRatioOption('SEDANG (1/2)', 0.5),
                              _buildRatioOption('KECIL (1/4)', 0.25),
                            ],
                          ),
                         const SizedBox(height: 12),
                       ],
                       const SizedBox(height: 12),
                       const Text('UKURAN KERTAS PRINTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                       Row(
                         children: [
                           Expanded(
                             child: RadioListTile<int>(
                               title: const Text('58mm', style: TextStyle(fontSize: 12)),
                               value: 58,
                               groupValue: _paperSize,
                               onChanged: (v) => _setPaperSize(v!),
                               contentPadding: EdgeInsets.zero,
                             ),
                           ),
                           Expanded(
                             child: RadioListTile<int>(
                               title: const Text('80mm', style: TextStyle(fontSize: 12)),
                               value: 80,
                               groupValue: _paperSize,
                               onChanged: (v) => _setPaperSize(v!),
                               contentPadding: EdgeInsets.zero,
                             ),
                           ),
                         ],
                       ),
                       const Divider(),
                       SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('TAMPILKAN VERSI APLIKASI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: const Text('MENAMPILKAN VERSI & BUILD DI BAGIAN BAWAH STRUK.', style: TextStyle(fontSize: 9)),
                            value: _showAppVersion, 
                            activeColor: MetroColors.primary,
                            onChanged: _toggleAppVersion,
                       ),
                    ],
                  ),
                ),
              ),
              
              const VerticalDivider(width: 48),

              // RIGHT PANEL: PREVIEW
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    const Text('PREVIEW TAMPILAN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))]
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // LOGO
                              if (_isLogoEnabled && _logoPath != null && File(_logoPath!).existsSync())
                                  Column(
                                    children: [
                                      Image.file(
                                          File(_logoPath!), 
                                          key: ValueKey(_logoKey),
                                          height: 80, 
                                          fit: BoxFit.contain,
                                          errorBuilder: (ctx, err, stack) => const Column(
                                              children: [
                                                  Icon(Icons.broken_image, size: 40, color: Colors.orange),
                                                  Text("Gagal memuat gambar", style: TextStyle(fontSize: 8))
                                              ],
                                          ),
                                      ),
                                      // Text("Path: ${_logoPath!.split('/').last}", style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                    ],
                                  )
                              else
                                  const Icon(Icons.store, size: 64, color: Colors.black26),
                              
                              const SizedBox(height: 12),
                              if (!_isLogoEnabled) ...[
                                  Text(_info['name']!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                                  Text(_info['address']!, style: const TextStyle(fontSize: 10, color: Colors.black54), textAlign: TextAlign.center),
                                  Text(_info['mobile']!, style: const TextStyle(fontSize: 10, color: Colors.black54), textAlign: TextAlign.center),
                              ],
                              
                              const Divider(color: Colors.black26, height: 24),
                              
                              _buildPreviewRow("No: ${_info['invoice_prefix']}${DateFormat('yyMMdd').format(DateTime.now())}${_startIndexController.text.padLeft(4, '0')}", "Kasir: Admin", bold: true),
                              _buildPreviewRow(DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), "DINE IN"),
                              
                              const Divider(color: Colors.black26, height: 24),
                              
                              _buildPreviewRow("Nasi Goreng Spesial", "25.000"),
                              Padding(padding: const EdgeInsets.only(left: 12), child: _buildPreviewRow("1 x 25.000", "25.000", small: true)),
                              const SizedBox(height: 4),
                              _buildPreviewRow("Es Teh Manis", "10.000"),
                              Padding(padding: const EdgeInsets.only(left: 12), child: _buildPreviewRow("2 x 5.000", "10.000", small: true)),

                              const Divider(color: Colors.black26, height: 24),
                              
                              _buildPreviewRow(_info['lbl_subtotal']!, "35.000"),
                              _buildPreviewRow(_info['lbl_tax']! + " (10%)", "3.500"),
                              const Divider(color: Colors.black26),
                              _buildPreviewRow(_info['lbl_total']!, "38.500", bold: true, size: 14),
                              
                              const Divider(color: Colors.black26, height: 24),
                              Text(_info['footer_text']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              if (_showAppVersion) ...[
                                const SizedBox(height: 4),
                                Text("${AppConfig.appName} $_appVersion", textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.black45)),
                              ],
                              const SizedBox(height: 24),
                              const Text('*** PREVIEW ***', style: TextStyle(color: Colors.black12, fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    MetroButton(
                      label: 'TEST PRINT STRUK',
                      icon: Icons.print,
                      color: MetroColors.text,
                      onPressed: _testPrint
                    )
                  ],
                ),
              )
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11))),
          Expanded(child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String left, String right, {bool bold = false, bool small = false, double? size}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: size ?? (small ? 9 : 11))),
          Text(right, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: size ?? (small ? 9 : 11))),
        ],
      ),
    );
  }

  Widget _buildRatioOption(String label, double val) {
    return InkWell(
      onTap: () => _setLogoRatio(val),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            child: Radio<double>(
              value: val,
              groupValue: _logoRatio,
              onChanged: (v) => _setLogoRatio(v!),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
