import 'package:flutter/material.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/db_helper.dart';

class PosCartController extends ChangeNotifier {
  final List<CartItem> _cart = [];
  List<Discount> _activeDiscounts = [];
  List<Tax> _activeTaxes = [];
  bool _roundingEnabled = false;
  int _roundingIncrement = 100;
  bool _taxEnabled = true;
  bool _discountEnabled = true;
  
  // Getters
  List<CartItem> get cart => List.unmodifiable(_cart);
  bool get hasItems => _cart.isNotEmpty;
  double get subtotal {
    double s = _cart.fold(0, (sum, item) => sum + item.total);
    return s.isNaN ? 0 : s;
  }
  
  List<Discount> get activeDiscounts => List.unmodifiable(_activeDiscounts);
  List<Tax> get activeTaxes => List.unmodifiable(_activeTaxes);
  Map<int, List<int>> get discountVariations => Map.unmodifiable(_discountVariations);
  Map<String, dynamic>? get activeLocalDiscount => _activeLocalDiscount;
  
  double _manualDiscountVal = 0;
  bool _manualDiscountIsPercent = false;
  
  double get manualDiscountVal => _manualDiscountVal;
  bool get manualDiscountIsPercent => _manualDiscountIsPercent;

  double get manualDiscountAmount {
      if (_manualDiscountVal <= 0) return 0;
      double amt = _manualDiscountIsPercent ? (subtotal * (_manualDiscountVal / 100)) : _manualDiscountVal;
      return amt.isNaN ? 0 : amt;
  }

  double get manualDiscount => manualDiscountAmount;

  // Computed Getters
  double get calculatedDiscount {
    double totalDisc = 0;
    
    // 1. Item-level discounts already calculated in _updateItemDiscounts
    for (var item in _cart) {
        totalDisc += item.itemDiscount;
    }
    return totalDisc.isNaN ? 0 : totalDisc;
  }

  /// Choose the larger discount between product-specific discounts and global manual/customer discounts.
  /// This prevents additive overlapping and negative totals (e.g., 100% global + 5% product).
  double get effectiveDiscount {
      double pDisc = calculatedDiscount;
      double mDisc = manualDiscountAmount;
      return (pDisc > mDisc) ? pDisc : mDisc;
  }

  double get calculatedTax {
    if (!_taxEnabled) return 0;
    double taxable = subtotal - effectiveDiscount;
    if (taxable < 0) taxable = 0;
    
    double taxAmt = 0;
    for (var t in _activeTaxes) {
        taxAmt += taxable * (t.amount / 100);
    }
    return taxAmt.isNaN ? 0 : taxAmt;
  }

  double get finalTotal {
    double total = subtotal - effectiveDiscount + calculatedTax;
    if (total < 0 || total.isNaN) total = 0;
    
    if (_roundingEnabled) {
      if (_roundingIncrement == 100) return (total / 100).round() * 100.0;
      if (_roundingIncrement == 500) return (total / 500).round() * 500.0;
      if (_roundingIncrement == 1000) return (total / 1000).round() * 1000.0;
    }
    return total;
  }
  
  // Actions

  void addToCart(Product product, double price, List<ModifierOption> selectedModifiers, String note) {
      // Logic to find existing item with same mods
      final existingIndex = _cart.indexWhere((item) {
          if (item.product.id != product.id || item.price != price) return false;
          // Compare modifiers length
          if (item.selectedModifiers.length != selectedModifiers.length) return false;
          // Compare modifier IDs
          for (var sm in selectedModifiers) {
              if (!item.selectedModifiers.any((o) => o.id == sm.id)) return false;
          }
          // Compare note
          if (item.note != note) return false;
          return true;
      });

      if (existingIndex >= 0) {
          _cart[existingIndex].qty++;
      } else {
          _cart.add(CartItem(
            product: product, 
            price: price, 
            selectedModifiers: selectedModifiers,
            note: note,
            itemDiscount: 0,
            qty: 1
          ));
      }
      _recalculateDiscounts();
      notifyListeners();
  }

  void updateQty(int index, int delta) {
      if (index < 0 || index >= _cart.length) return;
      
      _cart[index].qty += delta;
      if (_cart[index].qty <= 0) {
          _cart.removeAt(index);
      }
      _recalculateDiscounts();
      notifyListeners();
  }

  void removeFromCart(Product product, {bool isDecrease = true}) {
      // Find the last item in cart that matches this product
      // We use lastIndexWhere because users usually want to remove the most recently added item
      final index = _cart.lastIndexWhere((item) => item.product.id == product.id);
      if (index >= 0) {
          if (isDecrease) {
              updateQty(index, -1);
          } else {
              _cart.removeAt(index);
              _recalculateDiscounts();
              notifyListeners();
          }
      }
  }
  
  void updateNote(int index, String newNote) {
      if (index < 0 || index >= _cart.length) return;
      _cart[index].note = newNote;
      notifyListeners();
  }

  void setManualDiscount(double val, bool isPercent) {
      _manualDiscountVal = val;
      _manualDiscountIsPercent = isPercent;
      notifyListeners();
  }

  void clearCart() {
      _manualDiscountVal = 0;
      _manualDiscountIsPercent = false;
      _cart.clear();
      notifyListeners();
  }

  Map<int, List<int>> _discountVariations = {}; // discountId -> list of variationIds
  Map<String, dynamic>? _activeLocalDiscount;
  int? _currentPriceGroupId;

  void setCartItems(List<CartItem> items) {
      _cart.clear();
      _cart.addAll(items);
      _recalculateDiscounts();
      notifyListeners();
  }

  void loadConfig({
      required List<Discount> discounts, 
      required List<Tax> taxes, 
      required bool rounding, 
      required int increment,
      required Map<int, List<int>> discountVariations,
      Map<String, dynamic>? localDiscount,
      int? currentPriceGroupId,
      Map<int, double>? displayPrices,
      bool taxEnabled = true,
      bool discountEnabled = true
  }) {
      _activeDiscounts = discounts;
      _activeTaxes = taxes;
      _roundingEnabled = rounding;
      _roundingIncrement = increment;
      _discountVariations = discountVariations;
      _activeLocalDiscount = localDiscount;
      _currentPriceGroupId = currentPriceGroupId;
      _taxEnabled = taxEnabled;
      _discountEnabled = discountEnabled;

      // Update existing items' prices if displayPrices is provided
      if (displayPrices != null) {
          for (var item in _cart) {
              if (displayPrices.containsKey(item.product.id)) {
                  item.price = displayPrices[item.product.id]!;
              } else {
                  // Fallback to standard price if not in group
                  item.price = item.product.price;
              }
          }
      }

      _recalculateDiscounts();
      notifyListeners();
  }

  void updatePriceGroup(int? priceGroupId) {
     if (_currentPriceGroupId != priceGroupId) {
         _currentPriceGroupId = priceGroupId;
         // Note: Call loadConfig to refresh item prices from DB
         _recalculateDiscounts();
         notifyListeners();
     }
  }

  // Internal Logic
  void _recalculateDiscounts() {
       // Logic: Item-level and manual discounts are now calculated regardless of the UI setting flag
       // to ensure automatic customer group discounts (like MISYA) persist even if the manual button is off.
       for (var item in _cart) {
           // Default discount: item discount * qty (if any logic updates this)
           double disc = item.product.discountNominal * item.qty;
          
          for (var d in _activeDiscounts) {
              if (d.spg != null && d.spg!.isNotEmpty) {
                  if (_currentPriceGroupId == null || d.spg != _currentPriceGroupId.toString()) continue;
              }
              final vars = _discountVariations[d.id] ?? [];
              bool matches = false;
              if (vars.contains(item.product.id)) matches = true;
              if (!matches && d.brandId != null && item.product.brandId == d.brandId) matches = true;
              if (!matches && d.categoryId != null && item.product.categoryId == d.categoryId) matches = true;
              
              if (matches) {
                  if (d.type == 'fixed') disc += d.amount * item.qty;
                  else disc += (item.price * item.qty) * (d.amount / 100);
              }
          }

          if (_activeLocalDiscount != null) {
               final lCatId = _activeLocalDiscount!['category_id'];
               if (lCatId != null && item.product.categoryId == lCatId) {
                   final lVal = _activeLocalDiscount!['discount_value'] as double;
                   if (_activeLocalDiscount!['discount_type'] == 'nominal') disc += lVal * item.qty;
                   else disc += (item.price * item.qty) * (lVal / 100);
               }
          }
          
          item.itemDiscount = disc;
      }
  }
}
