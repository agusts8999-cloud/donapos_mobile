import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/utils_label_printer.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class ProductLabelFinal extends StatefulWidget {
  const ProductLabelFinal({super.key});

  @override
  State<ProductLabelFinal> createState() => _ProductLabelFinalState();
}

class _ProductLabelFinalState extends State<ProductLabelFinal> {
  // Data
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  
  // State
  bool _isLoading = false;
  bool _isDataLoaded = false;
  
  // Settings
  bool _labelPrinterEnabled = false;
  String? _labelPrinterAddress;
  int? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    debugPrint("[LabelFinal] initState fired");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings().then((_) {
        if (mounted) _refreshData();
      });
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _labelPrinterEnabled = prefs.getBool('label_printer_enabled') ?? false;
          _labelPrinterAddress = prefs.getString('label_printer_address');
        });
      }
    } catch (e) {
      debugPrint("[LabelFinal] Prefs Error: $e");
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    debugPrint("[LabelFinal] Querying Database...");
    try {
      final db = await DatabaseHelper.instance.database;
      final cats = await db.query('categories', orderBy: 'name ASC');
      final prods = await db.query('products', orderBy: 'name ASC');
      
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(cats);
        _products = List<Map<String, dynamic>>.from(prods);
        _isDataLoaded = true;
        _filterProducts();
        _isLoading = false;
      });
      debugPrint("[LabelFinal] Data load success: ${_products.length} products");
    } catch (e) {
      debugPrint("[LabelFinal] DB Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProducts() {
    _filteredProducts = _products.where((p) {
      final matchesSearch = p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategoryId == null || p['category_id'] == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _toggleProductLabel(int id, int currentVal) async {
    final newVal = currentVal == 1 ? 0 : 1;
    setState(() {
      final idx = _products.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        _products[idx] = {..._products[idx], 'needs_label': newVal};
        _filterProducts();
      }
    });
    final db = await DatabaseHelper.instance.database;
    await db.update('products', {'needs_label': newVal}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[LabelFinal] build fired");
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.85).clamp(400.0, 850.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(400.0, 600.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          border: Border.all(color: MetroColors.primary, width: 2),
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: MetroColors.primary,
              child: Row(
                children: [
                   const Icon(Icons.label, color: Colors.white, size: 20),
                   const SizedBox(width: 10),
                   const Expanded(
                     child: Text("PENGATURAN LABEL PRODUK", 
                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.close, color: Colors.white, size: 20), 
                     onPressed: () => Navigator.pop(context),
                     padding: EdgeInsets.zero,
                     constraints: const BoxConstraints(),
                   )
                ],
              ),
            ),

            // PRINTER INFO
            _buildStatusRow(),

            // MAIN AREA
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : !_isDataLoaded 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 50, color: Colors.black12),
                            const SizedBox(height: 16),
                            const Text("MEMUAT DATA PRODUK...", style: TextStyle(color: Colors.black38, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _refreshData,
                              icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                              label: const Text("MUAT ULANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MetroColors.primary,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildProductListArea(),
            ),

            // FOOTER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  if (_isDataLoaded)
                    Text("${_filteredProducts.length} PRODUK", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black45)),
                  const Spacer(),
                  SizedBox(
                    height: 38,
                    width: 120,
                    child: MetroButton(label: "TUTUP", color: MetroColors.primary, onPressed: () => Navigator.pop(context)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MetroColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.print, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _labelPrinterAddress ?? "PRINTER BELUM SET", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Text("AUTO", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 30,
            width: 45,
            child: FittedBox(
              child: Switch(value: _labelPrinterEnabled, activeColor: MetroColors.primary, onChanged: (v) async {
                final prefs = await SharedPreferences.getInstance();
                setState(() => _labelPrinterEnabled = v);
                await prefs.setBool('label_printer_enabled', v);
              }),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 30,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  await showDialog(context: context, builder: (_) => const LabelScannerFinal());
                  if (mounted) _loadSettings();
                } catch (e) {
                  debugPrint("[LabelFinal] Scanner dialog error: $e");
                }
              },
              icon: const Icon(Icons.bluetooth_searching, size: 14, color: Colors.white),
              label: const Text("SCAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MetroColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProductListArea() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: "CARI PRODUK...",
                      hintStyle: const TextStyle(fontSize: 10, color: Colors.black26),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black12), borderRadius: BorderRadius.zero),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black12), borderRadius: BorderRadius.zero),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: MetroColors.primary), borderRadius: BorderRadius.zero),
                    ),
                    onChanged: (v) { setState(() { _searchQuery = v; _filterProducts(); }); },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: MetroColors.primary, size: 20), 
                onPressed: _refreshData,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredProducts.length,
            itemBuilder: (c, i) {
               final p = _filteredProducts[i];
               final bool active = (p['needs_label'] ?? 0) == 1;
               return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: active ? MetroColors.primary : Colors.black12),
                    color: active ? MetroColors.primary.withOpacity(0.05) : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.label, size: 14, color: active ? MetroColors.primary : Colors.black26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p['name'].toString().toUpperCase(), 
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? MetroColors.primary : Colors.black87),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        width: 40,
                        child: FittedBox(
                          child: Switch(
                            value: active, 
                            activeColor: MetroColors.primary, 
                            onChanged: (v) => _toggleProductLabel(p['id'], p['needs_label'] ?? 0),
                          ),
                        ),
                      )
                    ],
                  ),
               );
            }
          ),
        )
      ],
    );
  }
}

class LabelScannerFinal extends StatefulWidget {
  const LabelScannerFinal({super.key});
  @override
  State<LabelScannerFinal> createState() => _LabelScannerFinalState();
}

class _LabelScannerFinalState extends State<LabelScannerFinal> {
  List<BluetoothInfo> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _scan() async {
    try {
      var list = await LabelPrinterUtil.getBondedDevices();
      if(mounted) setState(() { _devices = list; _isLoading = false; });
    } catch(e) { if(mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("PILIH PRINTER LABEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            const Divider(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _devices.isEmpty
                  ? const Center(child: Text("TIDAK ADA PERANGKAT DITEMUKAN", style: TextStyle(color: Colors.black38, fontSize: 11)))
                  : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.print, color: Colors.black54),
                        title: Text(_devices[i].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                        subtitle: Text(_devices[i].macAdress, style: const TextStyle(fontSize: 10)),
                        onTap: () async {
                           await LabelPrinterUtil.connect(_devices[i].macAdress);
                           final p = await SharedPreferences.getInstance();
                           p.setString('label_printer_address', _devices[i].macAdress);
                           if(mounted) Navigator.pop(context);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _scan, child: const Text("SCAN ULANG")),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
              ],
            )
          ],
        ),
      ),
    );
  }
}
