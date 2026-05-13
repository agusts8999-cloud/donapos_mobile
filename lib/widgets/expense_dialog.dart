import 'package:donapos_mobile/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:intl/intl.dart';

class ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) return const TextEditingValue();
    final intValue = int.parse(text);
    final formatted = NumberFormat("#,##0", "id_ID").format(intValue);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpenseDialog extends StatefulWidget {
  const ExpenseDialog({super.key});

  @override
  State<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<ExpenseDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getAllExpenseCategories();
    setState(() {
      _categories = cats;
      if (cats.isNotEmpty) {
        _selectedCategoryId = cats.first['id'];
      }
      _isLoading = false;
    });
  }

  Future<void> _saveExpense() async {
    if (_amountController.text.isEmpty) return;
    String cleanAmount = _amountController.text.replaceAll('.', '');
    double? amount = double.tryParse(cleanAmount);
    if (amount == null || amount <= 0) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseHelper.instance.insertLocalExpense({
        'category_id': _selectedCategoryId,
        'final_total': amount,
        'transaction_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'additional_notes': _noteController.text,
        'is_synced': 0
      });

      ApiService().syncExpenses();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 800, // Widened for horizontal layout
        decoration: BoxDecoration(
          color: MetroColors.surface,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: MetroColors.primary, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: MetroColors.primary,
              child: const Row(
                children: [
                   Icon(Icons.outbox_outlined, color: Colors.white),
                   SizedBox(width: 12),
                   Text(
                    'CATAT PENGELUARAN (BIAYA)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NOMINAL RP
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOMINAL (RP)',
                              style: TextStyle(fontSize: 7.7, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: MetroColors.white,
                                border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
                              ),
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, ThousandSeparatorFormatter()],
                                style: const TextStyle(fontSize: 10.8, color: MetroColors.text, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  hintText: 'CONTOH: 50.000',
                                  hintStyle: TextStyle(color: Colors.black26, fontSize: 9.3),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // KATEGORI BIAYA
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KATEGORI BIAYA',
                              style: TextStyle(fontSize: 7.7, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoading)
                              const Center(child: DonaposLoader(size: 60))
                            else if (_categories.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                                    SizedBox(height: 8),
                                    Text('KATEGORI BIAYA BELUM ADA', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              )
                            else
                              Container(
                                height: 50,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.black.withOpacity(0.1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedCategoryId,
                                    isExpanded: true,
                                    style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.bold, fontSize: 11),
                                    items: _categories.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c['id'],
                                        child: Text(c['name'].toString().toUpperCase()),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() => _selectedCategoryId = val);
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // CATATAN
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CATATAN / KEPERLUAN',
                              style: TextStyle(fontSize: 7.7, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: MetroColors.white,
                                border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
                              ),
                              child: TextField(
                                controller: _noteController,
                                style: const TextStyle(fontSize: 10.8, color: MetroColors.text, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  hintText: 'CONTOH: BELI BENSIN, LLA',
                                  hintStyle: TextStyle(color: Colors.black26, fontSize: 9.3),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 150,
                        child: MetroButton(
                          label: 'BATAL',
                          onPressed: () => Navigator.pop(context),
                          color: Colors.black.withOpacity(0.05),
                          textColor: Colors.black38,
                          isSecondary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 250,
                        child: MetroButton(
                          label: 'SIMPAN BIAYA',
                          onPressed: _saveExpense,
                          color: MetroColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
