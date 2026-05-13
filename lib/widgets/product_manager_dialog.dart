import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:intl/intl.dart';

class ProductManagerDialog extends StatefulWidget {
  const ProductManagerDialog({super.key});

  @override
  State<ProductManagerDialog> createState() => _ProductManagerDialogState();
}

class _ProductManagerDialogState extends State<ProductManagerDialog> {
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Selection State
  int? _selectedProductId;
  String _selectedField = ''; // 'price' or 'discount'
  String _numpadBuffer = ''; 

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllProducts();
    if (mounted) {
      setState(() {
        _products = data.map((e) => Product.fromMap(e)).toList();
        _isLoading = false;
      });
    }
  }

  void _onCellTap(Product p, String field, double currentValue) {
    setState(() {
      _selectedProductId = p.id;
      _selectedField = field;
      _numpadBuffer = currentValue.toInt().toString();
    });
  }

  void _onNumpadInput(String value) {
    if (_selectedProductId == null) return;

    setState(() {
      if (value == 'C') {
        _numpadBuffer = '0';
      } else if (value == 'BACK') {
        if (_numpadBuffer.isNotEmpty) {
          _numpadBuffer = _numpadBuffer.substring(0, _numpadBuffer.length - 1);
        }
        if (_numpadBuffer.isEmpty) _numpadBuffer = '0';
      } else if (value == 'ENTER') {
        _saveChange();
      } else {
        if (_numpadBuffer == '0') _numpadBuffer = value;
        else _numpadBuffer += value;
      }
    });
  }

  void _saveChange() async {
    if (_selectedProductId == null) return;
    
    final productIndex = _products.indexWhere((p) => p.id == _selectedProductId);
    if (productIndex == -1) return;

    final product = _products[productIndex];
    final newValue = double.tryParse(_numpadBuffer) ?? 0;

    Map<String, dynamic> data = product.toMap();
    
    if (_selectedField == 'price') {
       data['price'] = newValue;
    } else if (_selectedField == 'discount') {
       data['discount_nominal'] = newValue;
    }

    try {
      await DatabaseHelper.instance.insertProduct(data);
      
      setState(() {
        _products[productIndex] = Product.fromMap(data);
        _selectedProductId = null; 
        _selectedField = '';
        _numpadBuffer = '';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan!'), duration: Duration(milliseconds: 500)));
    } catch (e) {
      print("Error saving product: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat("#,##0", "id_ID");
    final size = MediaQuery.of(context).size;

    return GlassDialog(
        title: 'MANAJEMEN MASTER PRODUK (HARGA STANDAR)',
        icon: Icons.price_change,
        width: size.width * 0.95,
        height: size.height * 0.9,
        content: Row(
          children: [
            // LEFT PANEL: LIST
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    // Search
                     Container(
                       padding: const EdgeInsets.all(8),
                       color: Colors.white,
                       child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search, size: 18),
                                hintText: 'Cari nama produk...',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        ),
                     ),
                     
                     // Table Header
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       color: Colors.grey[200],
                       child: const Row(
                         children: [
                           Expanded(flex: 4, child: Text('PRODUK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                           Expanded(flex: 2, child: Text('HARGA STANDAR', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                           SizedBox(width: 8),
                           Expanded(flex: 2, child: Text('DISKON (CASH)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                         ],
                       ),
                     ),
                     
                     // List
                     Expanded(
                       child: _isLoading 
                        ? const Center(child: DonaposLoader(size: 60)) 
                        : ListView.separated(
                           padding: EdgeInsets.zero,
                           itemCount: _filteredProducts.length,
                           separatorBuilder: (_, __) => const Divider(height: 1),
                           itemBuilder: (ctx, i) {
                             final p = _filteredProducts[i];
                             final isSelected = _selectedProductId == p.id;
                             
                             return Container(
                               color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                               child: Row(
                                 children: [
                                   Expanded(
                                     flex: 4, 
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                         Text('ID: ${p.id}', style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                       ],
                                     )
                                   ),
                                   
                                   // Price Cell
                                   Expanded(
                                     flex: 2,
                                     child: _EditableCell(
                                       value: isSelected && _selectedField == 'price' ? _numpadBuffer : currency.format(p.price),
                                       isSelected: isSelected && _selectedField == 'price',
                                       onTap: () => _onCellTap(p, 'price', p.price),
                                       color: MetroColors.primary,
                                     ),
                                   ),
                                   
                                   const SizedBox(width: 8),
                                   
                                   // Discount Cell
                                   Expanded(
                                     flex: 2,
                                     child: _EditableCell(
                                       value: isSelected && _selectedField == 'discount' ? _numpadBuffer : currency.format(p.discountNominal),
                                       isSelected: isSelected && _selectedField == 'discount',
                                       onTap: () => _onCellTap(p, 'discount', p.discountNominal),
                                       color: MetroColors.retailPrimary,
                                     ),
                                   ),
                                 ],
                                ),
                             );
                           },
                        ),
                     )
                  ],
                ),
              ),
            ),
            
            // RIGHT PANEL: NUMPAD
            Expanded(
              flex: 4,
              child: Container(
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: Column(
                  children: [
                    // Display Active Item Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: MetroColors.primary,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11)),
                      ),
                      child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('EDITING:', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 1),
                           Text(
                             _selectedProductId != null ? _getProductById(_selectedProductId!)?.name ?? '-' : 'PILIH PRODUK',
                             style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                             maxLines: 1, overflow: TextOverflow.ellipsis
                           ),
                           const SizedBox(height: 1),
                           Text(
                             _selectedField == 'price' ? 'HARGA STANDAR' : (_selectedField == 'discount' ? 'DISKON NOMINAL' : '-'),
                             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)
                           )
                         ],
                      ),
                    ),
                    
                    // Buffer Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      alignment: Alignment.centerRight,
                      color: Colors.grey[50],
                      child: Text(
                        _selectedProductId == null ? '' : currency.format(int.tryParse(_numpadBuffer) ?? 0),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Numpad Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: Column(
                          children: [
                            Expanded(child: Row(children: [_btn('7'), _btn('8'), _btn('9')])),
                            Expanded(child: Row(children: [_btn('4'), _btn('5'), _btn('6')])),
                            Expanded(child: Row(children: [_btn('1'), _btn('2'), _btn('3')])),
                            Expanded(child: Row(children: [_btn('C', color: Colors.red[50], textColor: Colors.red), _btn('0'), _btn('BACK', icon: Icons.backspace)])),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 45,
                              width: double.infinity,
                              child: MetroButton(
                                label: 'SIMPAN',
                                icon: Icons.check,
                                color: MetroColors.primary,
                                onPressed: _selectedProductId != null ? () => _onNumpadInput('ENTER') : () {},
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        )
    );
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
  }
  
  Product? _getProductById(int id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  Widget _btn(String label, {Color? color, Color textColor = Colors.black87, IconData? icon}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(6),
          elevation: 1,
          child: InkWell(
            onTap: _selectedProductId == null ? null : () => _onNumpadInput(label),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(6)
              ),
              child: icon != null 
                  ? Icon(icon, color: textColor, size: 18)
                  : Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableCell extends StatelessWidget {
  final String value;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _EditableCell({required this.value, required this.isSelected, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? color : Colors.black12)
        ),
        alignment: Alignment.centerRight,
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 11
          ),
        ),
      ),
    );
  }
}
