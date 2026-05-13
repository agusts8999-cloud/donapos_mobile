import 'package:flutter/material.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/api_service.dart';

class PosTransactionController {
    final ApiService _apiService = ApiService();

    Future<int> saveTransaction({
        required List<CartItem> cart,
        required String saleType,
        required double subtotal,
        required double discount,
        required double tax,
        required double total,
        required String paymentMethod,
        required String cashierName,
        int? cashierId,
        required double amountPaid,
        required double changeAmount,
        int? tableId,
        int? customerId,
        String? customerName,
        int? existingTxId,
        int shiftId = 1,
        int? resServiceStaffId,
        int pax = 0,
        List<Map<String, dynamic>>? payments,
        String status = 'final',
        bool isHold = false,
        String? invoiceNo,
        double manualDiscount = 0,
        String? holdNote,
    }) async {
        
        // --- 1. CONSTRUCT UNIFIED TEMPLATE ---
        final tx = PosTransaction(
            id: existingTxId,
            invoiceNo: invoiceNo,
            saleType: saleType,
            tableId: tableId,
            subtotal: subtotal,
            discount: discount,
            manualDiscount: manualDiscount,
            tax: tax,
            total: total,
            status: status,
            isHold: isHold,
            holdNote: holdNote,
            createdAt: DateTime.now(),
            paymentMethod: paymentMethod,
            cashierId: cashierId,
            cashierName: cashierName,
            customerId: customerId,
            customerName: customerName,
            amountPaid: amountPaid,
            changeAmount: changeAmount,
            resServiceStaffId: resServiceStaffId,
            pax: pax,
            shiftId: shiftId,
            items: cart.map((item) => PosTransactionItem(
                productId: item.product.id,
                qty: item.qty,
                price: item.price,
                discount: item.itemDiscount,
                note: item.note,
                modifiers: item.selectedModifiers.map((mod) => PosTransactionModifier(
                    optionId: mod.id,
                    name: mod.name,
                    price: mod.price,
                )).toList(),
            )).toList(),
            payments: (payments ?? []).map((p) => PosTransactionPayment(
                method: p['method'] ?? 'cash',
                amount: (p['amount'] as num).toDouble(),
                note: p['note'] ?? '',
            )).toList(),
        );

        // --- 2. PERSIST VIA UNIFIED DB METHOD ---
        return await DatabaseHelper.instance.persistTransaction(tx);
    }

    Future<void> syncTransactions() async {
        await _apiService.syncTransactions();
    }
}
