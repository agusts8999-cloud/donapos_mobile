import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/utils_scaler.dart';
import 'package:donapos_mobile/widgets/digital_clock.dart';

import 'dart:ui';

class PosAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isClockedIn;
  final String businessName;
  final String cashierName;
  final String invoiceNumber;
  final String saleTypeLabel;
  final String? selectedTableName;
  final String? selectedCustomerName;
  final String? selectedWaiterName;
  final bool hasCartItems;
  final bool isResuming;
  final ScrollController headerScrollController;
  final ScrollController actionsScrollController;
  final VoidCallback onMenuPressed;
  final VoidCallback onSaleTypePressed;
  final VoidCallback onHoldListPressed;
  final VoidCallback onTablePressed;
  final VoidCallback onBillPressed;
  final VoidCallback onKitchenPrintPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onScanPressed;
  final VoidCallback onCustomerPressed;
  final VoidCallback onWaiterPressed;
  final VoidCallback onDiscountPressed;
  final bool discountEnabled;
  final bool isScanMode;
  final Function(PointerDownEvent)? onActionsPointerDown;
  final Function(PointerUpEvent)? onActionsPointerUp;
  final VoidCallback onSyncPressed;
  final VoidCallback onCalculatorPressed;
  final bool calculatorEnabled;
  final bool billEnabled;
  final bool kitchenEnabled;
  final int unsyncedCount;
  final bool isDemo;
  final VoidCallback onCloseAppPressed;

  const PosAppBar({
    super.key,
    required this.isClockedIn,
    required this.businessName,
    required this.cashierName,
    required this.invoiceNumber,
    required this.saleTypeLabel,
    this.selectedTableName,
    required this.hasCartItems,
    this.selectedCustomerName,
    this.selectedWaiterName,
    required this.isResuming,
    required this.headerScrollController,
    required this.actionsScrollController,
    required this.onMenuPressed,
    required this.onSaleTypePressed,
    required this.onHoldListPressed,
    required this.onTablePressed,
    required this.onBillPressed,
    required this.onKitchenPrintPressed,
    required this.onSearchPressed,
    required this.onScanPressed,
    required this.onCustomerPressed,
    required this.onWaiterPressed,
    required this.onDiscountPressed,
    required this.onSyncPressed,
    required this.onCalculatorPressed,
    required this.calculatorEnabled,
    required this.billEnabled,
    required this.kitchenEnabled,
    required this.discountEnabled,
    required this.isScanMode,
    required this.unsyncedCount,
    this.isDemo = false,
    this.onActionsPointerDown,
    this.onActionsPointerUp,
    required this.onCloseAppPressed,
  });

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return AppBar(
      backgroundColor: MetroColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.white, size: 28.sc),
        onPressed: onMenuPressed,
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8.sc,
                      height: 8.sc,
                      decoration: BoxDecoration(
                          color: isClockedIn ? Colors.greenAccent : Colors.white24,
                          shape: BoxShape.circle,
                          boxShadow: isClockedIn
                              ? [
                                  BoxShadow(
                                      color: Colors.greenAccent.withOpacity(0.5),
                                      blurRadius: 4.sc,
                                      spreadRadius: 1.sc)
                                ]
                              : null),
                    ),
                    SizedBox(width: 8.sc),
                    Text(businessName.toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13.sp,
                            letterSpacing: 1.2.sc,
                            color: Colors.white)),
                    SizedBox(width: 12.sc),
                    // Sync Status Indicator
                    if (isDemo)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.sc, vertical: 2.sc),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4.sc),
                          ),
                          child: Text("DEMO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10.sp)),
                        )
                    else
                        _buildSyncIndicator(context),
                  ],
                ),
                SizedBox(height: 2.sc),
                SingleChildScrollView(
                  controller: headerScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('${lp.translate('cashier')}: $cashierName'.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.white60,
                              fontWeight: FontWeight.bold)),
                      SizedBox(width: 8.sc),
                      Container(width: 1.sc, height: 8.sc, color: Colors.white12),
                      SizedBox(width: 8.sc),
                      Text('INV: $invoiceNumber'.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: MetroColors.accent,
                              fontWeight: FontWeight.w900)),
                      SizedBox(width: 8.sc),
                      Container(width: 1.sc, height: 8.sc, color: Colors.white12),
                      SizedBox(width: 8.sc),
                      Container(width: 1.sc, height: 8.sc, color: Colors.white12),
                      SizedBox(width: 8.sc),
                      DigitalClock(
                        style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.66,
          child: Listener(
            onPointerDown: onActionsPointerDown,
            onPointerUp: onActionsPointerUp,
            child: SingleChildScrollView(
              controller: actionsScrollController,
              scrollDirection: Axis.horizontal,
              reverse: false, // Normal direction for marquee
              child: Row(
              children: [
                _buildAppBarAction(Icons.qr_code_scanner, lp.translate('scan'), onScanPressed, 
                    color: isScanMode ? Colors.white : Colors.white70,
                    isFeatured: isScanMode ? true : false,
                    backgroundColor: isScanMode ? MetroColors.error : null
                ),
                _buildAppBarAction(Icons.search, lp.translate('search'), onSearchPressed, color: Colors.white),
                _buildAppBarAction(Icons.shopping_bag, saleTypeLabel,
                    onSaleTypePressed,
                    color: MetroColors.accent),
                _buildAppBarAction(Icons.list_alt, lp.translate('hold'), onHoldListPressed),
                _buildAppBarAction(Icons.person,
                    selectedCustomerName?.toUpperCase() ?? lp.translate('customer'), onCustomerPressed,
                    color: Colors.greenAccent),
                _buildAppBarAction(Icons.badge,
                    selectedWaiterName?.toUpperCase() ?? 'WAITER', onWaiterPressed,
                    color: Colors.cyanAccent),
                  _buildAppBarAction(Icons.table_restaurant,
                      selectedTableName?.toUpperCase() ?? lp.translate('table'), onTablePressed),
                if (billEnabled)
                  _buildAppBarAction(Icons.receipt_long, 'BILL', onBillPressed, color: Colors.yellowAccent),
                if (discountEnabled)
                  _buildAppBarAction(Icons.percent, lp.translate('discount'), onDiscountPressed, color: Colors.orangeAccent),
                if (calculatorEnabled)
                  _buildAppBarAction(Icons.calculate, 'KALKULATOR', onCalculatorPressed, color: Colors.greenAccent),
                if (kitchenEnabled)
                  _buildAppBarAction(Icons.restaurant_menu, lp.translate('kitchen'), onKitchenPrintPressed,
                      isFeatured: true),
              ],
            ),
          ),
        ),
        ),
        SizedBox(width: 8.sc),
      ],
    );
  }

  Widget _buildAppBarAction(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white, bool isFeatured = false, Color? backgroundColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.sc, horizontal: 4.sc),
      child: Material(
        color: backgroundColor ?? (isFeatured ? Colors.white : Colors.black45),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: isFeatured ? Colors.transparent : Colors.white38, width: 1.2.sc),
          borderRadius: BorderRadius.zero,
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.sc),
            alignment: Alignment.center,
            child: Row(
              children: [
                Icon(icon,
                    size: 16.sc, color: isFeatured ? MetroColors.primary : color),
                SizedBox(width: 8.sc),
                Text(label,
                    style: TextStyle(
                        color: isFeatured ? MetroColors.primary : Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.sc)),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSyncIndicator(BuildContext context) {
    bool isSynced = unsyncedCount == 0;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSyncPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 10.sc, vertical: 4.sc),
          decoration: BoxDecoration(
            color: isSynced ? Colors.green.withOpacity(0.2) : MetroColors.error.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4.sc),
            border: Border.all(
              color: isSynced ? Colors.greenAccent : MetroColors.error,
              width: 1.5.sc,
            ),
            boxShadow: [
              if (!isSynced)
                BoxShadow(
                  color: MetroColors.error.withOpacity(0.3),
                  blurRadius: 8.sc,
                  spreadRadius: 1.sc,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSynced ? Icons.cloud_done : Icons.cloud_upload,
                size: 14.sc,
                color: isSynced ? Colors.greenAccent : MetroColors.error,
              ),
              SizedBox(width: 6.sc),
              Text(
                isSynced ? "SYNCED" : "$unsyncedCount PENDING",
                style: TextStyle(
                  color: isSynced ? Colors.greenAccent : Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5.sc,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
