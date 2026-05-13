import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/utils_label_printer.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class ProductLabelV3 extends StatefulWidget {
  const ProductLabelV3({super.key});

  @override
  State<ProductLabelV3> createState() => _ProductLabelV3State();
}

class _ProductLabelV3State extends State<ProductLabelV3> {
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
    debugPrint("[LabelV3] initState");
    _loadSettingsOnly();
  }

  Future<void> _loadSettingsOnly() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _labelPrinterEnabled = prefs.getBool('label_printer_enabled') ?? false;
        _labelPrinterAddress = prefs.getString('label_printer_address');
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    debugPrint("[LabelV3] Refreshing data from DB...");
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
    } catch (e) {
      debugPrint("[LabelV3] Error: $e");
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Material( // Wrap with Material to ensure text colors work
        color: Colors.white,
        borderOnForeground: true,
        child: Container(
          width: 850,
          height: 600,
          decoration: BoxDecoration(
            border: Border.all(color: MetroColors.primary, width: 2),
          ),
          child: Column(
            children: [
              // HEADER (Gunakan warna hitam agar teks putih lebih terlihat kontras)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                color: MetroColors.primary,
                child: Row(
                  children: [
                    const Icon(Icons.label, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Text("PENGATURAN LABEL PRODUK (V3)", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))
                  ],
                ),
              ),

              // PRINTER STATUS
              _buildStatusRow(),

              // MAIN BODY
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : !_isDataLoaded 
                        ? _buildInitialState() 
                        : _buildProductListArea(),
                ),
              ),

              // FOOTER
              Container(
                padding: const EdgeInsets.all(15),
                color: Colors.grey.shade100,
                child: Row(
                  children: [
                    if (_isDataLoaded) Text("DITEMUKAN: ${_filteredProducts.length} PRODUK", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black45)),
                    const Spacer(),
                    SizedBox(
                      width: 150,
                      height: 45,
                      child: MetroButton(label: "SELESAI", color: MetroColors.primary, onPressed: () => Navigator.pop(context))
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.print, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(child: Text(_labelPrinterAddress ?? "PRINTER BELUM DIHUBUNGKAN", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
          const Text("AUTO", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
          Switch(activeColor: MetroColors.primary, value: _labelPrinterEnabled, onChanged: (v) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() => _labelPrinterEnabled = v);
            await prefs.setBool('label_printer_enabled', v);
          }),
          const SizedBox(width: 12),
          SizedBox(
            height: 35,
            child: MetroButton(
              label: "HUBUNGKAN", 
              color: MetroColors.secondary, 
              isSecondary: true, 
              onPressed: () async {
                await showDialog(context: context, builder: (_) => const LabelScannerV3());
                _loadSettingsOnly();
              }
            )
          )
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 60, color: Colors.black12),
          const SizedBox(height: 16),
          const Text("DATA PRODUK PERLU DIMUAT", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 24),
          SizedBox(
            width: 250,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text("MUAT DAFTAR PRODUK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: MetroColors.primary, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
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
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black12), color: Colors.white),
                  child: TextField(
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(hintText: "CARI PRODUK...", border: InputBorder.none, icon: Icon(Icons.search, size: 18)),
                    onChanged: (v) { setState(() { _searchQuery = v; _filterProducts(); }); },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(icon: const Icon(Icons.refresh, color: MetroColors.primary), onPressed: _refreshData),
            ],
          ),
        ),
        SizedBox(
          height: 35,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _catChip(null, "SEMUA"),
              ..._categories.map((c) => _catChip(c['id'], c['name'].toString().toUpperCase())),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 4.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: _filteredProducts.length,
            itemBuilder: (c, i) {
              final p = _filteredProducts[i];
              final bool active = (p['needs_label'] ?? 0) == 1;
              return InkWell(
                onTap: () => _toggleProductLabel(p['id'], p['needs_label'] ?? 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: active ? MetroColors.primary.withOpacity(0.05) : Colors.white, border: Border.all(color: active ? MetroColors.primary : Colors.black12, width: active ? 1.5 : 1)),
                  child: Row(
                    children: [
                      Expanded(child: Text(p['name'].toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: active ? MetroColors.primary : Colors.black87), overflow: TextOverflow.ellipsis)),
                      Switch(value: active, activeColor: MetroColors.primary, onChanged: (v) => _toggleProductLabel(p['id'], p['needs_label'] ?? 0))
                    ],
                  ),
                ),
              );
            }
          ),
        )
      ],
    );
  }

  Widget _catChip(int? id, String label) {
    bool selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black54)),
        selected: selected,
        onSelected: (v) { setState(() { _selectedCategoryId = id; _filterProducts(); }); },
        selectedColor: MetroColors.primary,
        backgroundColor: Colors.black.withOpacity(0.05),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }
}

class LabelScannerV3 extends StatefulWidget {
  const LabelScannerV3({super.key});
  @override
  State<LabelScannerV3> createState() => _LabelScannerV3State();
}

class _LabelScannerV3State extends State<LabelScannerV3> {
  List<BluetoothInfo> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  void _scan() async {
    setState(() => _isLoading = true);
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("PILIH PRINTER LABEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
            const Divider(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(_devices[i].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                      subtitle: Text(_devices[i].macAdress, style: const TextStyle(fontSize: 10)),
                      onTap: () async {
                        await LabelPrinterUtil.connect(_devices[i].macAdress);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('label_printer_address', _devices[i].macAdress);
                        if(mounted) Navigator.pop(context);
                      },
                    ),
                  ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL"))
          ],
        ),
      ),
    );
  }
}
