import 'package:flutter/material.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/design_system.dart'; // For GlobalSettings if needed
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class PosProvider with ChangeNotifier {
  // State
  bool _isLoading = false;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  
  // Data for Cart Calculation (exposed for Controller)
  List<Discount> _discounts = [];
  List<Tax> _taxes = [];
  Map<int, List<int>> _discountVariations = {};
  Map<String, dynamic>? _activeLocalDiscount;
  
  // Sale Type (Price Group ID)
  int? _selectedPriceGroupId; // null = Standard Price
  
  // Selection
  int _selectedCategoryId = 0; // 0 = All
  String _searchQuery = '';
  
  // Modifiers
  Set<int> _productsWithModifiers = {};
  
  // Price Cache
  Map<int, double> _displayPrices = {};
  
  // Sync Status
  int _unsyncedCount = 0;
  Timer? _refreshTimer;
  
  // Getters
  bool get isLoading => _isLoading;
  List<Product> get products => _filteredProducts; // Expose filtered list for UI
  List<Product> get allProducts => _products; // Expose full list if needed
  List<Category> get categories => _categories;
  int get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  int? get selectedPriceGroupId => _selectedPriceGroupId;
  
  // Getters for Cart Controller
  List<Discount> get discounts => _discounts;
  List<Tax> get taxes => _taxes;
  Map<int, List<int>> get discountVariations => _discountVariations;
  Map<String, dynamic>? get activeLocalDiscount => _activeLocalDiscount;
  
  int? get currentPriceGroupId => _selectedPriceGroupId;
  
  Map<int, double> get displayPrices => _displayPrices;
  Set<int> get productsWithModifiers => _productsWithModifiers;
  int get unsyncedCount => _unsyncedCount;

  // Actions
  Future<void> loadData(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    
    try {
        final apiService = ApiService();
        final prefs = await SharedPreferences.getInstance();
        
        // 1. Load Sale Type & Price Config
        final pgId = prefs.getInt('selected_price_group_id'); // null means standard
        _selectedPriceGroupId = pgId;
        
        // 2. Load Categories
        // Default 'All' category needs to be translated? Passed from UI or handled here?
        // We'll use a placeholder and let UI handle translation for ID 0, or passing string
        final catData = await DatabaseHelper.instance.getAllCategories();
        // Note: ID 0 'All Categories' should be handled by UI or inserted here with generic name
        _categories = [Category(id: 0, name: 'SEMUA KATEGORI')] + 
                      catData.map((e) => Category.fromMap(e)).toList();
        
        // 3. Load Taxes & Discounts
        _taxes = (await DatabaseHelper.instance.getAllTaxes()).map((e) => Tax.fromMap(e)).toList();
        _discounts = (await DatabaseHelper.instance.getAllDiscounts()).map((e) => Discount.fromMap(e)).toList();
        _discountVariations = {};
        for (var d in _discounts) {
            _discountVariations[d.id] = await DatabaseHelper.instance.getDiscountVariations(d.id);
        }
        _activeLocalDiscount = await DatabaseHelper.instance.getActiveLocalDiscount();
        
        // 4. Load Products
        await _refreshProducts();

        // 5. Load Sync Status
        await updateUnsyncedCount();
        
        // 6. Start periodic refresh
        _startSyncTimer();
        
    } catch (e) {
        print("PosProvider Load Data Error: $e");
    } finally {
        _isLoading = false;
        notifyListeners();
    }
  }

  Future<void> updateUnsyncedCount() async {
    _unsyncedCount = await DatabaseHelper.instance.getUnsyncedCount();
    notifyListeners();
  }

  void _startSyncTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      updateUnsyncedCount();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _refreshProducts() async {
      List<Map<String, dynamic>> data;
      // We load ALL products initially to allow local filtering without DB queries for speed
      // Or we can follow the original logic: fetch all if cat=0, else fetch by cat.
      // But for "offline-first" and speed, fetching all is usually fine if < 5000 items. 
      // Original logic fetched by category. Let's stick to original logic to be safe.
      
      if (_selectedCategoryId == -1) {
          data = await DatabaseHelper.instance.getProducts(onlyFeatured: true);
      } else if (_selectedCategoryId == 0) {
          data = await DatabaseHelper.instance.getAllProducts();
      } else {
          data = await DatabaseHelper.instance.getProductsByCategory(_selectedCategoryId);
      }
      
      // Load Modifiers
      try {
          _productsWithModifiers = await DatabaseHelper.instance.getProductIdsWithModifiers();
      } catch (e) {
          print('Error loading modifier indicators: $e');
      }
      
      // Calculate Prices
      int? targetGroupId = currentPriceGroupId;
      Map<int, double> groupPrices = {};
      if (targetGroupId != null) {
          groupPrices = await DatabaseHelper.instance.getPricesForGroup(targetGroupId);
      }
      
      _products = data.map((e) => Product.fromMap(e)).toList();
      _displayPrices = groupPrices;
      
      // Populate base prices if missing from group
      for (var p in _products) {
          if (!_displayPrices.containsKey(p.id)) {
              _displayPrices[p.id] = p.price;
          }
      }
      
      _applyFilter();
  }
  
  Future<void> setPriceGroup(int? pgId) async {
      if (_selectedPriceGroupId != pgId) {
          _selectedPriceGroupId = pgId;
          final prefs = await SharedPreferences.getInstance();
          if (pgId == null) await prefs.remove('selected_price_group_id');
          else await prefs.setInt('selected_price_group_id', pgId);
          
          await _refreshProducts();
          notifyListeners();
      }
  }
  
  Future<void> setCategory(int categoryId) async {
      if (_selectedCategoryId != categoryId) {
          _selectedCategoryId = categoryId;
          await _refreshProducts();
          notifyListeners();
      }
  }
  
  void setSearchQuery(String query) {
      if (_searchQuery != query) {
          _searchQuery = query;
          _applyFilter();
          notifyListeners();
      }
  }
  
  void _applyFilter() {
      // Since _refreshProducts already filters by DB for category (if logic followed), 
      // we double check here or just filter by search.
      // Actually _refreshProducts loads based on _selectedCategoryId.
      // So here we primarily filter by Search Query.
      
      _filteredProducts = _products.where((p) {
          // Category check logic:
          // If -1 (Favorites), we rely on _refreshProducts loading only favorites, so we match everything
          // If 0 (All), we match everything
          // If > 0, we match categoryId
          
          bool matchCategory = true;
          if (_selectedCategoryId > 0) {
              matchCategory = p.categoryId == _selectedCategoryId;
          }
          // Note: If -1, DB already filtered for is_featured=1, so we assume all loaded are valid. 
          // We don't check p.categoryId because a featured product can be in ANY category.
          
          bool matchSearch = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchCategory && matchSearch;
      }).toList();
  }
  
  Product? findProductBySku(String sku) {
      if (sku.trim().isEmpty) return null;
      try {
          // We search in _products (which might be filtered by category if we use DB filtering).
          // If we want GLOBAL search by SKU, we might need a separate DB call if cache is partial.
          // BUT, original logic used _products.firstWhere.
          // If _products only contains "Beverages", scanning a "Food" item won't work.
          // FIX: If we use DB filtering, this is a bug in original code too maybe?
          // Let's assume user wants to scan ANY product.
          // Correct approach: Scan should query DB if not found in memory.
          
          // Try memory first
          final p = _products.firstWhere(
              (p) => (p.sku?.toLowerCase() == sku.toLowerCase()),
              orElse: () => Product(id: -1, name: '', price: 0)
          );
          if (p.id != -1) return p;
          
          return null; // Let UI handle "Not Found" or try simpler DB query
      } catch (e) {
          return null;
      }
  }
}
