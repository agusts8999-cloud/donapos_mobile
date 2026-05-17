import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/models/admin_sync_preset.dart';
import 'package:donapos_mobile/services/admin_sync_runner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AdminSyncUiMode { simple, advanced }

class SyncItem {
  final String id;
  final String label;
  final IconData icon;
  final Future<dynamic> Function({Function(String)? onProgress}) task;
  bool isSelected = true;
  String status = 'WAITING'; // WAITING, SYNCING, OK, ERROR
  String? progressText;

  SyncItem({required this.id, required this.label, required this.icon, required this.task});
}
class SyncCenterDialog extends StatefulWidget {
  final bool isLoading; 
  final ApiService apiService;
  final Function(String title, Future<dynamic> Function({Function(String)? onProgress}) task) onSyncTask;
  final VoidCallback? onSyncComplete;
  final bool isContentOnly;
  final String? username;
  final double? width;
  final double? height;
  final AdminSyncUiMode uiMode;
  final List<String>? initialPresetIds;

  const SyncCenterDialog({
    super.key,
    required this.isLoading,
    required this.apiService,
    required this.onSyncTask,
    this.onSyncComplete,
    this.isContentOnly = false,
    this.username,
    this.width,
    this.height,
    this.uiMode = AdminSyncUiMode.advanced,
    this.initialPresetIds,
  });

  @override
  State<SyncCenterDialog> createState() => _SyncCenterDialogState();
}

class _SyncCenterDialogState extends State<SyncCenterDialog> {
  late List<SyncItem> _items;
  bool _isSyncing = false;
  String _activeUsername = 'LOADING...';
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isCredentialsVisible = false;
  bool _isAdminAuthReady = true;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  bool _showAdvancedList = false;
  String _simpleStatus = 'Siap mengunduh data bisnis ke tablet.';
  double _simpleProgress = 0;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initItems();
    _loadUsername();
  }

  void _loadUsername() async {
      final prefs = await SharedPreferences.getInstance();
      final name = widget.username ?? prefs.getString('last_user_name') ?? 'SYSTEM/MACHINE';
      
      final savedSyncUser = prefs.getString('sync_admin_user');
      final savedSyncPass = prefs.getString('sync_admin_pass');
      
      if (mounted) {
          setState(() {
              _activeUsername = name.toUpperCase();
              
              if (savedSyncUser != null && savedSyncPass != null) {
                  _isAdminAuthReady = true;
                  if (_activeUsername != savedSyncUser.toUpperCase()) {
                      _userController.text = savedSyncUser;
                      _passController.text = savedSyncPass;
                  }
              } else {
                  // Jika belum ada data admin yang disimpan via Admin Menu
                  _isAdminAuthReady = false;
              }
          });
      }
  }

  static const Map<String, IconData> _syncIcons = {
    'PRD': Icons.inventory_2,
    'IMG': Icons.image,
    'MOD': Icons.set_meal,
    'CAT': Icons.category,
    'TAB': Icons.table_bar,
    'STF': Icons.people,
    'TXS': Icons.receipt_long,
    'DSC': Icons.discount,
    'PMT': Icons.payments,
    'CUS': Icons.contact_page,
    'CGR': Icons.groups,
    'SPG': Icons.sell,
    'BIZ': Icons.business,
    'XCT': Icons.list_alt,
    'EXP': Icons.upload_file,
    'ATT': Icons.fingerprint,
    'SAL': Icons.cloud_upload,
  };

  void _initItems() {
    final tasks = createAdminSyncItems(widget.apiService);
    _items = tasks
        .map(
          (t) => SyncItem(
            id: t.id,
            label: t.label,
            icon: _syncIcons[t.id] ?? Icons.sync,
            task: t.task,
          ),
        )
        .toList();
  }

  Future<void> _runSimplePreset(List<String> presetIds, {required String startMessage}) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _simpleProgress = 0;
      _simpleStatus = startMessage;
      _logs.clear();
    });

    final result = await runAdminSyncPreset(
      api: widget.apiService,
      presetIds: presetIds,
      onStep: (current, total, label) {
        if (!mounted) return;
        setState(() {
          _simpleProgress = current / total;
          _simpleStatus = 'Langkah $current dari $total: $label';
        });
      },
      onLog: (line) {
        if (mounted) setState(() => _logs.add(line));
      },
    );

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _simpleProgress = result.success ? 1 : _simpleProgress;
      _simpleStatus = result.success
          ? 'Selesai! $startMessage'
          : (result.errorMessage ?? 'Proses gagal. Coba lagi.');
    });

    if (result.success && widget.onSyncComplete != null) {
      widget.onSyncComplete!();
    }
  }

  Future<void> _startSync() async {
    setState(() {
      _isSyncing = true;
      _logs.clear();
      _logs.add('--- MEMULAI SINKRONISASI PADA ${DateTime.now().toString().split('.')[0]} ---');
    });
    
    if (mounted) {
      // 1. Cek jika ada input User/Pass manual
      if (_userController.text.isNotEmpty && _passController.text.isNotEmpty) {
          setState(() => _logs.add('! MENCOBA LOGIN MANUAL: ${_userController.text}...'));
          bool loginSuccess = await widget.apiService.login(_userController.text, _passController.text);
          if (loginSuccess) {
              setState(() {
                _logs.add('✓ LOGIN MANUAL BERHASIL.');
                _activeUsername = _userController.text.toUpperCase();
              });
          } else {
              setState(() {
                _logs.add('✗ LOGIN MANUAL GAGAL. CEK PASSWORD.');
                _isSyncing = false;
              });
              return; // Stop sync if manual login fails
          }
      }

      var headers = await widget.apiService.getHeaders();
      var token = headers['Authorization'];
      
      if (token == 'Bearer null' || token == null) {
          setState(() {
            _logs.add('! AKUN BELUM TERAUTENTIKASI (TOKEN KOSONG).');
            _logs.add('! MENCOBA LOGIN OTOMATIS (CLIENT AUTH)...');
          });
          
          bool authSuccess = await widget.apiService.authenticateClient();
          if (authSuccess) {
              setState(() => _logs.add('✓ LOGIN OTOMATIS BERHASIL. LANJUTKAN...'));
              headers = await widget.apiService.getHeaders();
          } else {
              setState(() {
                _logs.add('✗ LOGIN OTOMATIS GAGAL. CEK KONEKSI INTERNET.');
                _logs.add('  Saran: Pastikan Internet aktif atau Login Admin.');
              });
          }
      }
    }

    for (var item in _items) {
      if (!item.isSelected) continue;
      if (!mounted) break;

      setState(() {
        item.status = 'SYNCING';
        item.progressText = 'PROSES...';
      });

      try {
        final result = await item.task(onProgress: (p) {
          if (mounted) setState(() => item.progressText = p.toUpperCase());
        });

        if (mounted) {
          setState(() {
            item.status = 'OK';
            if (result is int) {
               item.progressText = '$result ITEM';
               _logs.add('✓ ${item.label}: Berhasil ($result Item)');
            } else if (result is Map && result.containsKey('count')) {
               item.progressText = '${result['count']} ITEM';
               _logs.add('✓ ${item.label}: Berhasil (${result['count']} Item)');
               if (result['logs'] != null && result['logs'] is List) {
                  for (var log in result['logs']) {
                    _logs.add('  > $log');
                  }
               }
            } else {
               item.progressText = 'DONE';
               _logs.add('✓ ${item.label}: Selesai');
            }
          });
          _scrollToBottom();
        }
      } catch (e, stack) {
        if (mounted) {
          setState(() {
            item.status = 'ERROR';
            item.progressText = 'GAGAL';
            _logs.add('✗ ${item.label}: Gagal ($e)');
            debugPrint('Sync Error Stack: $stack');
          });
          _scrollToBottom();
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _logs.add('--- SINKRONISASI SELESAI ---');
        
        // Uncheck successful items, keep failed ones checked
        for (var item in _items) {
          if (item.status == 'OK') {
            item.isSelected = false;
          }
        }
      });
      _scrollToBottom();
      if (widget.onSyncComplete != null) widget.onSyncComplete!();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildCredentialsInput() {
    if (!_isCredentialsVisible) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: Colors.black12))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 14, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('OTENTIKASI MANUAL (OVERRIDE)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: 'USERNAME',
                    prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.withOpacity(0.5)),
                  ),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'PASSWORD',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.withOpacity(0.5)),
                  ),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.grey, size: 24),
                onPressed: () {
                  _userController.clear();
                  _passController.clear();
                  setState(() => _isCredentialsVisible = false);
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          const Text('* Gunakan ini jika sinkronisasi gagal karena akses ditolak.', style: TextStyle(fontSize: 9, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    if (!_isAdminAuthReady && !widget.isContentOnly) {
        return GlassDialog(
            title: lp.translate('sync_center'),
            icon: Icons.sync,
            width: widget.width ?? 550,
            height: 450, // Updated height to prevent overflow
            content: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 60, color: Colors.orange),
                    const SizedBox(height: 24),
                    const Text(
                      'SINKRONISASI DINONAKTIFKAN',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Silakan masuk ke Admin Menu untuk mengaktifkan sinkronisasi oleh kasir.',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    MetroButton(
                      label: 'TUTUP',
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
            ),
        );
    }

    Widget mainContent = Column(
        children: [
          if (_showAdvancedList || widget.uiMode == AdminSyncUiMode.advanced) ...[
            _buildUtilityHeader(),
            const Divider(height: 1),
          ],
          Expanded(
            flex: 7,
            child: _showAdvancedList || widget.uiMode == AdminSyncUiMode.advanced
                ? ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildSyncItem(item);
                    },
                  )
                : _buildSimplePanel(),
          ),
          // Debug Console
          if ((_showAdvancedList || widget.uiMode == AdminSyncUiMode.advanced) &&
              (_logs.isNotEmpty || _isSyncing))
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E), // Visual VS Code background
                  border: Border(top: BorderSide(color: Colors.black, width: 2))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.black26,
                      child: Row(
                        children: [
                          const Icon(Icons.terminal, color: Colors.green, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'DETAIL PROSES',
                            style: TextStyle(
                              color: Colors.green.withOpacity(0.8),
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              letterSpacing: 1
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white38, size: 16),
                            onPressed: () {
                              final text = _logs.join('\n');
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logs copied to clipboard'), duration: Duration(seconds: 1))
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy Logs',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.white38, size: 16),
                            onPressed: () => setState(() => _logs.clear()),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear Logs',
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          String log = _logs[index];
                          Color logColor = const Color(0xFFD4D4D4);
                          if (log.contains('✓')) logColor = Colors.greenAccent;
                          if (log.contains('✗')) logColor = MetroColors.error;
                          if (log.contains('---')) logColor = Colors.blueAccent;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: logColor,
                                fontFamily: 'monospace',
                                fontSize: 9,
                                height: 1.4
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
          if (_showAdvancedList || widget.uiMode == AdminSyncUiMode.advanced) _buildFooter(),
        ],
    );

    if (widget.isContentOnly) {
      if (widget.uiMode == AdminSyncUiMode.simple && !_showAdvancedList) {
        return Column(
          children: [Expanded(child: _buildSimplePanel())],
        );
      }
      return mainContent;
    }

    return GlassDialog(
      title: lp.translate('sync_center'),
      icon: Icons.sync,
      width: widget.width ?? 550,
      height: widget.height ?? 750,
      content: mainContent,
    );
  }

  Widget _buildUtilityHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.black.withOpacity(0.02),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSyncing ? null : () {
                setState(() {
                  for (var item in _items) { item.isSelected = true; }
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: MetroColors.primary.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.check_box, size: 16, color: MetroColors.primary),
              label: Text('PILIH SEMUA', style: TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isSyncing ? null : () {
                setState(() {
                  for (var item in _items) { item.isSelected = false; }
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.black12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.check_box_outline_blank, size: 16, color: Colors.black26),
              label: const Text('BERSIHKAN', style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isSyncing ? null : () {
                setState(() {
                  for (var item in _items) { 
                    item.isSelected = (item.id == 'PRD' || item.id == 'IMG');
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.inventory, size: 16, color: Colors.orange),
              label: const Text('PILIH PRODUK', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _isSyncing ? null : () {
                setState(() {
                  for (var item in _items) { 
                    item.isSelected = (item.id == 'EXP' || item.id == 'SAL');
                  }
                });
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.green),
              label: const Text('POSTING BIAYA & PENJUALAN', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blueGrey.withOpacity(0.2))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    _activeUsername,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey,
                      letterSpacing: 0.5
                    ),
                  ),
                ],
              ),
            ),
            if (_isSyncing) ...[
              const SizedBox(width: 12),
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(MetroColors.primary)))
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSyncItem(SyncItem item) {
    bool isSyncing = item.status == 'SYNCING';
    bool isDone = item.status == 'OK';
    bool isError = item.status == 'ERROR';

    return InkWell(
      onTap: _isSyncing ? null : () {
        setState(() {
          item.isSelected = !item.isSelected;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: item.isSelected 
                ? const Icon(Icons.check_box, color: MetroColors.error, size: 22)
                : Icon(Icons.check_box_outline_blank, color: MetroColors.error.withOpacity(0.3), size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              item.label,
              style: TextStyle(
                color: item.isSelected ? MetroColors.error : Colors.black26,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('....................................................................', 
                  maxLines: 1, 
                  overflow: TextOverflow.clip,
                  style: TextStyle(color: Colors.black12, letterSpacing: 2),
                ),
              ),
            ),
            if (item.progressText != null)
              Text(
                item.progressText!,
                style: TextStyle(
                  color: isError ? MetroColors.error : (isDone ? Colors.green : Colors.black45),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            const SizedBox(width: 8),
            if (isDone)
              const Icon(Icons.check_circle, color: Colors.green, size: 16)
            else if (isError)
              const Icon(Icons.error, color: MetroColors.error, size: 16)
            else if (isSyncing)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(MetroColors.primary)))
            else
              Text('MENUNGGU', style: TextStyle(color: Colors.black12, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplePanel() {
    final isDownloadPreset = widget.initialPresetIds == null ||
        widget.initialPresetIds == AdminSyncPreset.downloadIds;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isDownloadPreset
                ? 'Unduh semua data bisnis yang dibutuhkan kasir (produk, kasir, meja, dll).'
                : 'Kirim data penjualan, biaya, dan absensi dari tablet ke server.',
            style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _isSyncing ? (_simpleProgress > 0 ? _simpleProgress : null) : 0,
              minHeight: 8,
              backgroundColor: Colors.black12,
              color: MetroColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _simpleStatus,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: MetroColors.text,
            ),
          ),
          const SizedBox(height: 24),
          MetroButton(
            label: _isSyncing
                ? 'SEDANG MEMPROSES...'
                : (isDownloadPreset ? 'UNDUH DATA BISNIS' : 'KIRIM KE SERVER'),
            icon: isDownloadPreset ? Icons.cloud_download : Icons.cloud_upload,
            onPressed: _isSyncing
                ? null
                : () => _runSimplePreset(
                      widget.initialPresetIds ?? AdminSyncPreset.downloadIds,
                      startMessage: isDownloadPreset
                          ? 'Mengunduh data bisnis...'
                          : 'Mengirim data ke server...',
                    ),
            isLarge: true,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isSyncing
                ? null
                : () => setState(() => _showAdvancedList = !_showAdvancedList),
            icon: Icon(_showAdvancedList ? Icons.expand_less : Icons.tune),
            label: Text(
              _showAdvancedList ? 'Sembunyikan daftar lengkap' : 'Tampilkan daftar lengkap (teknisi)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _showLogSheet(context),
                child: const Text('Lihat detail proses', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail proses',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: _logs
                    .map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    bool hasSelection = _items.any((i) => i.isSelected);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: const Border(top: BorderSide(color: Colors.black12))
      ),
      child: MetroButton(
        label: _isSyncing ? 'SEDANG MEMPROSES...' : 'MULAI PROSES TERPILIH',
        onPressed: (_isSyncing || !hasSelection) ? null : _startSync,
        color: MetroColors.primary,
        isLarge: false,
      ),
    );
  }
}
