import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/design_system.dart';
import 'dart:async';
import 'dart:io';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class PosProductGrid extends StatefulWidget {
  final List<Product> products;
  final Map<int, double> displayPrices;
  final List<CartItem> cart;
  final List<Discount> activeDiscounts;
  final Map<int, List<int>> discountVariations;
  final Map<String, dynamic>? activeLocalDiscount;
  final int? selectedPriceGroupId;
  final Function(Product, double) onProductTap;
  final Set<int> productsWithModifiers;
  final bool isAnimEnabled;

  const PosProductGrid({
    super.key,
    required this.products,
    required this.displayPrices,
    required this.cart,
    required this.activeDiscounts,
    required this.discountVariations,
    this.activeLocalDiscount,
    required this.selectedPriceGroupId,
    required this.onProductTap,
    this.productsWithModifiers = const {},
    this.isAnimEnabled = true,
  });

  @override
  State<PosProductGrid> createState() => _PosProductGridState();
}

class _PosProductGridState extends State<PosProductGrid> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isAutoScrolling = false;
  bool _isUserTouching = false;
  bool _scrollingDown = true;
  final Map<int, ImageProvider> _providerCache = {};
  final Map<String, bool> _localFileExistsCache = {};

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
    _precacheImages();
  }

  void _precacheImages() {
    // Only precache the first 50-100 products to avoid heavy initial load
    final productsToPrecache = widget.products.take(100).toList();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var p in productsToPrecache) {
        precacheImage(_getProductImageProvider(p), context);
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (widget.isAnimEnabled && !_isUserTouching && _scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll <= 0) return;

        if (_scrollingDown) {
          _scrollController.animateTo(
            maxScroll,
            duration: Duration(milliseconds: (maxScroll * 15).toInt().clamp(2000, 10000)),
            curve: Curves.linear,
          ).then((_) => _scrollingDown = false);
        } else {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: (maxScroll * 15).toInt().clamp(2000, 10000)),
            curve: Curves.linear,
          ).then((_) => _scrollingDown = true);
        }
      }
    });
  }

  bool _hasApplicableDiscount(Product p) {
    int? currentPriceGroupId = widget.selectedPriceGroupId;

    for (var d in widget.activeDiscounts) {
      if (d.spg != null && d.spg!.isNotEmpty) {
        if (currentPriceGroupId == null || d.spg != currentPriceGroupId.toString()) {
          continue;
        }
      }
      final vars = widget.discountVariations[d.id] ?? [];
      if (vars.contains(p.id)) return true;
      if (d.brandId != null && p.brandId == d.brandId) return true;
      if (d.categoryId != null && p.categoryId == d.categoryId) return true;
    }

    if (widget.activeLocalDiscount != null) {
        final lCatId = widget.activeLocalDiscount!['category_id'];
        if (lCatId == null || lCatId == p.categoryId) return true;
    }
    
    return false;
  }

  double _getDiscountedPrice(Product p, double basePrice) {
    double discounted = basePrice;
    
    for (var d in widget.activeDiscounts) {
      bool matches = false;
      final vars = widget.discountVariations[d.id] ?? [];
      if (vars.contains(p.id)) matches = true;
      if (!matches && d.brandId != null && p.brandId == d.brandId) matches = true;
      if (!matches && d.categoryId != null && p.categoryId == d.categoryId) matches = true;

      if (matches) {
          if (d.type == 'fixed') {
              discounted -= d.amount;
          } else {
              discounted -= (basePrice * (d.amount / 100));
          }
      }
    }

    if (widget.activeLocalDiscount != null) {
        final lType = widget.activeLocalDiscount!['discount_type'];
        final lVal = widget.activeLocalDiscount!['discount_value'] as double;
        final lCatId = widget.activeLocalDiscount!['category_id'];

        if (lCatId == null || lCatId == p.categoryId) {
            if (lType == 'nominal') {
                discounted -= lVal;
            } else {
                discounted -= (basePrice * (lVal / 100));
            }
        }
    }

    return discounted < 0 ? 0 : discounted;
  }

  int _getQty(int productId, double price) {
    final idx = widget.cart.indexWhere((i) => i.product.id == productId && i.price == price);
    return idx >= 0 ? widget.cart[idx].qty : 0;
  }

  void _showProductDetail(BuildContext context, Product p, double basePrice, double currentPrice) async {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final discountAmount = basePrice - currentPrice;
    String categoryName = 'UNCATEGORIZED';
    if (p.categoryId != null) {
      final cat = await DatabaseHelper.instance.getCategoryById(p.categoryId!);
      if (cat != null) categoryName = cat['name'] ?? 'UNCATEGORIZED';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        title: 'DETAIL PRODUK',
        icon: Icons.info_outline,
        width: 450.sc,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                Container(
                  height: 180.sc,
                  margin: EdgeInsets.only(bottom: 20.sc),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12, width: 1.sc),
                    image: DecorationImage(
                    image: _getProductImageProvider(p),
                    fit: BoxFit.cover
                  ),
                  ),
                ),
              Text(p.name.toUpperCase(), style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, letterSpacing: 1.sc)),
              SizedBox(height: 8.sc),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.sc, vertical: 4.sc),
                    color: MetroColors.primary.withOpacity(0.1),
                    child: Text(categoryName.toUpperCase(), style: TextStyle(color: MetroColors.primary, fontSize: 9.sp, fontWeight: FontWeight.w900, letterSpacing: 1.sc)),
                  ),
                  if (p.sku != null) ...[
                    SizedBox(width: 8.sc),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.sc, vertical: 4.sc),
                      color: Colors.black.withOpacity(0.05),
                      child: Text('SKU: ${p.sku}', style: TextStyle(color: Colors.black38, fontSize: 9.sp, fontWeight: FontWeight.w900, letterSpacing: 1.sc)),
                    ),
                  ],
                ],
              ),
              Divider(height: 40.sc, color: Colors.black12, thickness: 1.sc),
              _infoRow('HARGA STANDAR', currency.format(p.price)),
              if (discountAmount > 0) ...[
                Divider(height: 24.sc, color: Colors.black12, thickness: 1.sc),
                _infoRow('HARGA NORMAL', currency.format(basePrice)),
                _infoRow('POTONGAN DISKON', '- ${currency.format(discountAmount)}', color: MetroColors.error),
              ],
              SizedBox(height: 12.sc),
              Container(
                padding: EdgeInsets.all(16.sc),
                color: MetroColors.primary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('HARGA SAAT INI', style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1.sc)),
                    Text(currency.format(currentPrice), style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: MetroButton(
          label: 'TAMBAH KE KERANJANG',
          icon: Icons.add_shopping_cart,
          onPressed: () {
            Navigator.pop(ctx);
            widget.onProductTap(p, currentPrice);
          },
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color color = MetroColors.text}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.sc),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.black38, fontSize: 10.sp, fontWeight: FontWeight.w900, letterSpacing: 1.sc)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.sp)),
        ],
      ),
    );
  }

  final ApiService _apiService = ApiService();
  String? _baseUrl; // Clean Base (no /public)
  String? _rawBaseUrl; // Original Base (with /public if any)

  Future<void> _initBaseUrl() async {
    final url = await _apiService.getBaseUrl();
    if (mounted) {
      setState(() {
        _rawBaseUrl = url;
        _baseUrl = url.replaceAll('/public', '');
      });
    }
  }

  String _getAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (_baseUrl == null) return url;
    
    String path = url;
    if (path.startsWith('/')) path = path.substring(1);
    
    // Most reliable pattern for UltimatePOS/DonaPOS images is cleanBase + storage/
    if (path.contains('product_images') || path.contains('img/') || path.contains('uploads/')) {
         return '$_baseUrl/storage/$path';
    }
    
    // Fallback if no specific pattern matched
    return '$_baseUrl/$url';
  }

  @override
  void didUpdateWidget(PosProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _providerCache.clear();
      _precacheImages();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_baseUrl == null) _initBaseUrl();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    int crossAxisCount = 3;
    if (screenWidth >= 900) {
      crossAxisCount = 6;
    } else if (screenWidth >= 600) {
      crossAxisCount = isLandscape ? 5 : 4;
    } else {
      crossAxisCount = isLandscape ? 5 : 3;
    }

    if (widget.products.isEmpty) {
      return Container(
        color: Colors.white,
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.5,
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80.sc,
                color: MetroColors.text.withOpacity(0.05),
              ),
            ),
              SizedBox(height: 24.sc),
              Text(
                'TIDAK ADA PRODUK',
                style: TextStyle(
                  color: MetroColors.text.withOpacity(0.1),
                  fontWeight: FontWeight.w900,
                  fontSize: 18.sp,
                  letterSpacing: 1.5.sc,
                ),
              ),
              SizedBox(height: 8.sc),
              Text(
                'Silakan pilih kategori lain atau tambah produk baru',
                style: TextStyle(
                  color: MetroColors.text.withOpacity(0.3),
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        );
    }

    return Container(
      color: Colors.grey[200],
      child: Listener(
        onPointerDown: (_) {
           setState(() => _isUserTouching = true);
           _scrollController.jumpTo(_scrollController.offset); // Stop animation
        },
        onPointerUp: (_) {
           // Wait a bit before resuming autoscroll
           Future.delayed(const Duration(seconds: 5), () {
              if (mounted) setState(() => _isUserTouching = false);
           });
        },
        child: GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(12.sc, 0, 12.sc, 12.sc),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.92,
            crossAxisSpacing: 8.sc,
            mainAxisSpacing: 8.sc,
          ),
          itemCount: widget.products.length,
          itemBuilder: (ctx, i) {
            final p = widget.products[i];
            double price = widget.displayPrices[p.id] ?? p.price;
            final qty = _getQty(p.id, price);
            final hasImage = p.imageUrl != null && p.imageUrl!.isNotEmpty;
            final hasDiscount = _hasApplicableDiscount(p);
            final hasModifiers = widget.productsWithModifiers.contains(p.id);
      
            final tileColor = hasImage
                ? MetroColors.textDark
                : MetroColors.productColors[p.id % MetroColors.productColors.length];
      
            return Material(
              color: tileColor,
              child: InkWell(
                onTap: () => widget.onProductTap(p, price),
                onLongPress: () => _showProductDetail(
                  context, 
                  p, 
                  price, 
                  _hasApplicableDiscount(p) ? _getDiscountedPrice(p, price) : price
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: tileColor,
                    image: hasImage
                        ? DecorationImage(
                            image: _getProductImageProvider(p),
                            fit: BoxFit.cover,
                            opacity: 0.9) // Increased opacity for clarity
                        : null,
                    border: qty > 0
                        ? Border.all(color: MetroColors.primary, width: 4.sc)
                        : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: hasImage ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6), // Dark top for name
                          Colors.black.withOpacity(0.1), // Clear middle
                          Colors.black.withOpacity(0.7), // Dark bottom for price
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ) : null,
                    ),
                    padding: EdgeInsets.all(8.sc),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p.name.toUpperCase(),
                              maxLines: 2,
                               overflow: TextOverflow.ellipsis,
                               style: TextStyle(
                                   fontSize: 10.3.sp,
                                   fontWeight: FontWeight.w900,
                                   color: Colors.white,
                                   height: 1.25.sc,
                                   letterSpacing: 0.5.sc,
                                   shadows: [Shadow(color: Colors.black54, blurRadius: 4.sc)]
                               )),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasDiscount) 
                                   Text(
                                      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(price),
                                      style: TextStyle(
                                          fontSize: 8.5.sp,
                                          color: Colors.white70,
                                          shadows: [Shadow(color: Colors.black, blurRadius: 2.sc)],
                                          decoration: TextDecoration.lineThrough,
                                          fontWeight: FontWeight.bold),
                                   ),
                                Text(
                                  NumberFormat.currency(
                                          locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
                                      .format(hasDiscount ? _getDiscountedPrice(p, price) : price),
                                  style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.white,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 4.sc)],
                                      fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        // Badges Zone (Discount / Topping)
                        Positioned(
                          top: 8.sc,
                          left: 8.sc,
                          child: Row(
                            children: [
                              if (hasDiscount)
                                Container(
                                  padding: EdgeInsets.all(4.sc),
                                  decoration: const BoxDecoration(color: MetroColors.error, shape: BoxShape.circle),
                                  child: Icon(Icons.percent, size: 12.sc, color: Colors.white),
                                ),
                              if (hasDiscount && hasModifiers) SizedBox(width: 4.sc),
                              if (hasModifiers)
                                Container(
                                  padding: EdgeInsets.all(4.sc),
                                  decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                                  child: Icon(Icons.add, size: 12.sc, color: Colors.white),
                                ),
                            ],
                          ),
                        ),

                        if (qty > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.sc, vertical: 6.sc),
                              color: MetroColors.primary.withOpacity(0.7),
                              child: Text('X$qty',
                                  style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ImageProvider _getProductImageProvider(Product p) {
    if (_providerCache.containsKey(p.id)) return _providerCache[p.id]!;

    ImageProvider provider;
    
    // Check for asset path first
    if (p.imageUrl != null && p.imageUrl!.startsWith('assets/')) {
        provider = AssetImage(p.imageUrl!);
    } else if (p.localImagePath != null && p.localImagePath!.isNotEmpty) {
       bool exists = _localFileExistsCache[p.localImagePath!] ?? false;
       if (!exists) {
         exists = File(p.localImagePath!).existsSync();
         _localFileExistsCache[p.localImagePath!] = exists;
       }
       
       if (exists) {
         provider = FileImage(File(p.localImagePath!));
       } else {
         provider = CachedNetworkImageProvider(_getAbsoluteUrl(p.imageUrl));
       }
    } else {
       provider = CachedNetworkImageProvider(_getAbsoluteUrl(p.imageUrl));
    }
    
    _providerCache[p.id] = provider;
    return provider;
  }
}
