import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:intl/intl.dart';
import 'package:flutter_presentation_display/flutter_presentation_display.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/models/customer_display_setting.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:donapos_mobile/widgets/donapos_image.dart';

class CustomerDisplayScreen extends StatefulWidget {
  const CustomerDisplayScreen({super.key});

  @override
  State<CustomerDisplayScreen> createState() => _CustomerDisplayScreenState();
}

class _CustomerDisplayScreenState extends State<CustomerDisplayScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  double _total = 0;
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  CustomerDisplaySetting? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initListener();
  }

  Future<void> _loadSettings() async {
    final settings = await ApiService().getLocalCustomerDisplaySettings();
    if (settings != null) {
      if (mounted) setState(() => _settings = settings);
    }
    // Fetch latest in background
    ApiService().fetchCustomerDisplaySettings().then((remoteSettings) {
      if (remoteSettings != null && mounted) {
        setState(() => _settings = remoteSettings);
      }
    });
  }

  void _initListener() {
    FlutterPresentationDisplay().listenDataFromMainDisplay((data) {
      if (mounted && data is Map) {
        setState(() {
          if (data['items'] != null) {
            _cartItems = List<Map<String, dynamic>>.from(data['items']);
          }
          if (data['total'] != null) {
            _total = (data['total'] as num).toDouble();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If no settings yet, use default
    final themeColor = _settings?.themeColor != null 
        ? (Color(int.parse(_settings!.themeColor.replaceFirst('#', '0xff')))) 
        : MetroColors.primary;
        
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Side: Promotions / Welcome Screen
          Expanded(
            flex: 3,
            child: Container(
              color: themeColor.withOpacity(0.05),
              child: _buildPromotionalContent(themeColor),
            ),
          ),
          
          // Right Side: Cart Summary
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: Colors.grey.shade200, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    color: themeColor,
                    child: Text(
                      _settings?.welcomeText ?? "SISI PELANGGAN",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  
                  // List of Items
                  Expanded(
                    child: _cartItems.isEmpty
                        ? Center(
                            child: Text(
                              _settings?.welcomeText ?? "SELAMAT DATANG",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _cartItems.length,
                            separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100),
                            itemBuilder: (context, i) {
                              final item = _cartItems[i];
                              
                              // Simplified layout if requested by settings, but robust for now
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['name'] ?? '').toUpperCase(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          if (item['note'] != null && item['note']!.toString().isNotEmpty)
                                            Text(
                                              "(${item['note']})",
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      "x${item['qty']}",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      currency.format(item['total']),
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: MetroColors.secondary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Total Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("TOTAL BAYAR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            Text(
                              currency.format(_total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionalContent(Color themeColor) {
    if (_settings != null && _settings!.promoImages.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
            ),
            items: _settings!.promoImages.map((imageUrl) {
              return Builder(
                builder: (BuildContext context) {
                  return Container(
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      image: DecorationImage(
                          image: DonaposImage.provider(imageUrl),
                          fit: BoxFit.cover
                      )
                    ),
                  );
                },
              );
            }).toList(),
          ),
          // Gradient Overlay to ensure text visibility if needed
          /*
          Positioned(
             bottom: 0, left:0, right:0, height: 100,
             child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
          )
          */
        ],
      );
    }

    // Default Fallback Layout if no images
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, size: 80, color: themeColor),
                const SizedBox(height: 20),
                Text(
                  _settings?.welcomeText ?? "PROMOSI HARI INI",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Dapatkan diskon menarik setiap hari!",
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: Row(
            children: [
              Icon(Icons.local_cafe, color: themeColor),
              const SizedBox(width: 10),
              Text(
                "donaPOS Mobile",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
