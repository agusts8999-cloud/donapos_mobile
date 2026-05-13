import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/utils_scaler.dart';


class PosCartPanel extends StatelessWidget {
  final List<CartItem> cart;
  final double subtotal;
  final double calculatedDiscount;
  final double calculatedTax;
  final double finalTotal;
  final String interactionMode;
  final String invoiceNumber;
  final ValueChanged<String> onInteractionModeChanged;
  final VoidCallback onPayPressed;
  final VoidCallback? onHoldPressed;
  final Function(CartItem, int)? onItemTap;

  const PosCartPanel({
    super.key,
    required this.cart,
    required this.subtotal,
    required this.calculatedDiscount,
    required this.calculatedTax,
    required this.finalTotal,
    required this.interactionMode,
    required this.invoiceNumber,
    required this.onInteractionModeChanged,
    required this.onPayPressed,
    this.onHoldPressed,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final currency = NumberFormat.simpleCurrency(name: 'IDR', decimalDigits: 0);
    
    return Column(
      children: [
        // Transaction Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 8.sc, horizontal: 16.sc),
          color: Colors.black.withOpacity(0.04),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lp.translate('number').toUpperCase(), style: TextStyle(fontSize: 8.5.sp, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.sc)),
              Text(invoiceNumber, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: MetroColors.primary, letterSpacing: 1.2.sc)),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 48.sc, color: Colors.black.withOpacity(0.05)),
                      SizedBox(height: 16.sc),
                      Text(lp.translate('empty_cart').toUpperCase(),
                          style: TextStyle(
                              color: Colors.black12,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.sp,
                              letterSpacing: 2.sc)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16.sc),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.black.withOpacity(0.05), height: 1.sc),
                  itemBuilder: (ctx, i) {
                    final item = cart[i];
                    return InkWell(
                      onTap: () => onItemTap?.call(item, i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.sc),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name.toUpperCase(),
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 11.7.sp,
                                          fontWeight: FontWeight.w900)),
                                  Text('${item.qty}X @ ${currency.format(item.price)}',
                                      style: TextStyle(
                                          color: Colors.black38,
                                          fontSize: 8.9.sp,
                                          fontWeight: FontWeight.bold)),
                                  if (item.itemDiscount > 0)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.sc),
                                      child: Text(
                                        'Discount: -${currency.format(item.itemDiscount)}',
                                        style: TextStyle(
                                            color: MetroColors.error,
                                            fontSize: 8.5.sp,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  if (item.selectedModifiers.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.sc),
                                      child: Text(
                                        item.selectedModifiers.map((m) => m.name).join(', '),
                                        style: TextStyle(
                                            color: MetroColors.primary.withOpacity(0.7),
                                            fontSize: 8.5.sp,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  if (item.note.isNotEmpty)
                                    Padding(
                                      padding: EdgeInsets.only(top: 2.sc),
                                      child: Text(
                                        'Note: ${item.note}',
                                        style: TextStyle(
                                            color: Colors.orange.withOpacity(0.8),
                                            fontSize: 8.5.sp,
                                            fontStyle: FontStyle.italic,
                                            fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                    Text(currency.format(item.total),
                                        style: TextStyle(
                                            color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13.sp)),
                                    if (item.itemDiscount > 0)
                                        Text(currency.format(item.total - item.itemDiscount),
                                            style: TextStyle(
                                                color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 10.sp)),
                                ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Wrap summary in a constrained flexible area to allow scrolling if height is low (keyboard up)
        Flexible(
          flex: 0,
          child: SingleChildScrollView(
            child: _buildCartSummary(context, currency),
          ),
        ),
      ],
    );
  }

  Widget _buildCartSummary(BuildContext context, NumberFormat currency) {
    final lp = Provider.of<LanguageProvider>(context);
    return Container(
      padding: EdgeInsets.all(12.sc),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05), width: 1.sc))),
      child: Column(
        children: [
          _summaryRow(lp.translate('subtotal').toUpperCase(), currency.format(subtotal)),
          if (calculatedDiscount > 0)
            _summaryRow(lp.translate('discount').toUpperCase(), '-${currency.format(calculatedDiscount)}',
                color: MetroColors.error),
          if (calculatedTax > 0)
            _summaryRow(lp.translate('tax').toUpperCase(), currency.format(calculatedTax)),
          Divider(color: Colors.black12, height: 8.sc, thickness: 1.sc),
          _summaryRow(lp.translate('total').toUpperCase(), currency.format(finalTotal), isLarge: true),
          SizedBox(height: 12.sc),
          Row(
            children: [
              _buildInteractionBtn(Icons.add, 'add', MetroColors.retailPrimary),
              SizedBox(width: 8.sc),
              _buildInteractionBtn(Icons.remove, 'sub', MetroColors.kioskPrimary),
              SizedBox(width: 8.sc),
               _buildInteractionBtn(Icons.close, 'remove', MetroColors.error),
              SizedBox(width: 8.sc),
              Expanded(
                child: Material(
                  color: Colors.orange.withOpacity(0.1),
                  child: InkWell(
                    onTap: () {
                      GlobalSettings.playClick();
                      HapticFeedback.selectionClick();
                      onHoldPressed?.call();
                    },
                    child: Container(
                      height: 56.sc,
                      alignment: Alignment.center,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.pause, color: Colors.orange, size: 20.sc),
                              SizedBox(height: 2.sc),
                              Text("HOLD", style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.orange))
                          ]
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
          SizedBox(height: 8.sc),
          MetroButton(
            label: lp.translate('checkout').toUpperCase(),
            icon: Icons.payments,
            color: MetroColors.primary,
            onPressed: cart.isNotEmpty ? onPayPressed : null,
            isLarge: false,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isLarge = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isLarge ? 4.sc : 2.sc),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color ?? Colors.black38,
                  fontSize: isLarge ? 10.3.sp : 9.5.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5.sc)),
          Text(value,
              style: TextStyle(
                  color: color ?? (isLarge ? MetroColors.primary : Colors.black),
                  fontSize: isLarge ? 20.5.sp : 12.0.sp,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildInteractionBtn(IconData icon, String mode, Color color) {
    final isActive = interactionMode == mode;
    return Expanded(
      child: Material(
        color: isActive ? color : Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: () {
            GlobalSettings.playClick();
            HapticFeedback.selectionClick();
            onInteractionModeChanged(mode);
          },
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Icon(icon, color: isActive ? Colors.white : Colors.black26, size: 24),
          ),
        ),
      ),
    );
  }
}
