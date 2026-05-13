import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/utils_scaler.dart';

import 'package:donapos_mobile/screens/pos/components/topping_price_dialog.dart';

class PosModifierDialog extends StatefulWidget {
  final Product product;
  final List<ModifierOption> initialSelection;
  final String initialNote;

  const PosModifierDialog({
      Key? key, 
      required this.product,
      this.initialSelection = const [],
      this.initialNote = ''
  }) : super(key: key);

  @override
  _PosModifierDialogState createState() => _PosModifierDialogState();
}

class _PosModifierDialogState extends State<PosModifierDialog> {
  List<ProductModifier> _modifiers = [];
  List<ModifierOption> _selectedOptions = [];
  bool _isLoading = true;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedOptions = List.from(widget.initialSelection);
    _noteController.text = widget.initialNote;
    _loadModifiers();
  }

  Future<void> _loadModifiers() async {
    final sets = await DatabaseHelper.instance.getProductModifiers(widget.product.id);
    List<ProductModifier> mods = [];
    
    for (var s in sets) {
      final optionsMap = await DatabaseHelper.instance.getModifierOptions(s['set_id']);
      mods.add(ProductModifier(
        id: s['set_id'],
        name: s['set_name'],
        type: 'modifier',
        options: optionsMap.map((o) => ModifierOption.fromMap(o)).toList(),
      ));
    }

    setState(() {
      _modifiers = mods;
      _isLoading = false;
    });
  }



  void _toggleOption(ModifierOption option) async {
    HapticFeedback.lightImpact();
    
    final existingIndex = _selectedOptions.indexWhere((o) => o.id == option.id);
    
    if (existingIndex != -1) {
       setState(() {
         _selectedOptions.removeAt(existingIndex);
       });
    } else {
       final prefs = await SharedPreferences.getInstance();
       bool canEditPrice = prefs.getBool('topping_editing_enabled') ?? true;

       if (canEditPrice) {
           // Open Price Dialog
           double? price = await showDialog<double>(
             context: context,
             barrierDismissible: false,
             builder: (context) => ToppingPriceDialog(
               toppingName: option.name,
               initialPrice: option.price,
             ),
           );

           if (price != null && mounted) {
             setState(() {
               _selectedOptions.add(option.copyWith(price: price));
             });
           }
       } else {
           // Direct Add with Default Price
           setState(() {
               // Ensure we use the original price (default)
               _selectedOptions.add(option);
           });
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MetroColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: 500.sc,
        // Remove fixed padding here to allow flexible layout
        padding: EdgeInsets.all(24.sc), 
        // Use ConstrainedBox to respect screen boundaries
        constraints: BoxConstraints(
             maxHeight: MediaQuery.of(context).size.height * 0.9
        ),
        child: _isLoading
            ? Center(child: DonaposLoader(size: 60.sc))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAMBAHAN: ${widget.product.name.toUpperCase()}',
                    style: MetroTypography.h2.copyWith(color: MetroColors.primary, fontSize: (MetroTypography.h2.fontSize ?? 20).sp),
                  ),
                  SizedBox(height: 8.sc),
                  Text(
                    'Silahkan pilih topping atau instruksi tambahan',
                    style: MetroTypography.body.copyWith(color: Colors.white70, fontSize: (MetroTypography.body.fontSize ?? 14).sp),
                  ),
                  SizedBox(height: 24.sc),
                  
                  // Use Expanded for the scrolling area to take available space
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Modifiers List
                           ..._modifiers.map((mod) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 24.sc),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mod.name.toUpperCase(),
                                    style: MetroTypography.h3.copyWith(color: Colors.white, fontSize: (MetroTypography.h3.fontSize ?? 16).sp),
                                  ),
                                  SizedBox(height: 12.sc),
                                  Wrap(
                                    spacing: 12.sc,
                                    runSpacing: 12.sc,
                                    children: mod.options.map((opt) {
                                      // Find if selected to get real price
                                      var selected = _selectedOptions.firstWhere((o) => o.id == opt.id, orElse: () => opt); 
                                      bool isSelected = _selectedOptions.any((o) => o.id == opt.id);
                                      
                                      // Display price from selection if available, else standard
                                      double displayPrice = isSelected ? selected.price : opt.price;

                                      return SizedBox(
                                        width: 140.sc,
                                        child: MetroTile(
                                          label: opt.name,
                                          subLabel: isSelected 
                                              ? '+Rp ${displayPrice.toInt()}' // Always show price if selected
                                              : (displayPrice > 0 ? '+Rp ${displayPrice.toInt()}' : 'GRATIS'),
                                          icon: isSelected ? Icons.check_circle : Icons.add_circle_outline,
                                          color: isSelected ? MetroColors.retailPrimary : Colors.grey.shade400,
                                          onTap: () => _toggleOption(opt),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

                          // 2. Note Input
                          SizedBox(height: 12.sc),
                          Text('CATATAN / INSTRUKSI KHUSUS:', style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8.sc),
                          TextField(
                            controller: _noteController,
                            decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white, // White background
                                hintText: 'Contoh: Jangan pedas, pisah saos...',
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                                border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                                contentPadding: EdgeInsets.all(12.sc),
                                focusColor: MetroColors.primary
                            ),
                            style: TextStyle(color: Colors.black, fontSize: 14.sp, fontWeight: FontWeight.w500), // Black Text
                            maxLines: 2,
                          ),
                          SizedBox(height: 24.sc),
                        ],
                      ),
                    ),
                  ),
                  
                  // 3. Action Buttons (Pinned to bottom)
                  SizedBox(height: 16.sc),
                  Row(
                    children: [
                      Expanded(
                        child: MetroButton(
                          label: 'BATAL',
                          onPressed: () => Navigator.pop(context),
                          color: Colors.grey[800] ?? Colors.grey,
                        ),
                      ),
                      SizedBox(width: 16.sc),
                      Expanded(
                        child: MetroButton(
                          label: 'SIMPAN',
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.pop(context, {
                                'modifiers': _selectedOptions,
                                'note': _noteController.text.trim()
                            });
                          },
                          color: MetroColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
