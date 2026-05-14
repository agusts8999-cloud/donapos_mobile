import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class QrSettingsDialog extends StatefulWidget {
  const QrSettingsDialog({super.key});

  @override
  State<QrSettingsDialog> createState() => _QrSettingsDialogState();
}

class _QrSettingsDialogState extends State<QrSettingsDialog> {
  final _mainUrlController = TextEditingController();
  final _backOfficeUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _mainUrlController.text = prefs.getString('qr_main_url') ?? 'https://donapos.com';
    _backOfficeUrlController.text = prefs.getString('qr_backoffice_url') ?? 'https://donapos.serverzone.web.id';
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    
    final mainUrl = _mainUrlController.text.trim().isNotEmpty ? _mainUrlController.text.trim() : 'https://donapos.com';
    final boUrl = _backOfficeUrlController.text.trim().isNotEmpty ? _backOfficeUrlController.text.trim() : 'https://donapos.serverzone.web.id';
    
    await prefs.setString('qr_main_url', mainUrl);
    await prefs.setString('qr_backoffice_url', boUrl);
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan QR Code berhasil disimpan.')));
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _mainUrlController.dispose();
    _backOfficeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2, color: MetroColors.primary, size: 28.sc),
              SizedBox(width: 8.sc),
              const Text('PENGATURAN QR CODE LOGIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 400.sc,
        child: _isLoading
            ? const Center(child: DonaposLoader())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ubah alamat URL yang akan muncul pada QR Code di Layar Login. Jika dikosongkan, akan kembali ke alamat default.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  SizedBox(height: 24.sc),
                  MetroInput(
                    label: 'URL WEBSITE UTAMA',
                    controller: _mainUrlController,
                    hint: 'Contoh: https://perusahaan.com',
                  ),
                  SizedBox(height: 16.sc),
                  MetroInput(
                    label: 'URL BACK OFFICE / DASHBOARD',
                    controller: _backOfficeUrlController,
                    hint: 'Contoh: https://admin.perusahaan.com',
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: MetroColors.primary),
          onPressed: _isLoading ? null : _saveSettings,
          child: const Text('SIMPAN PENGATURAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
