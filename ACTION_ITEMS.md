> **Dokumen usang (v1.5.0, Jan 2026).** Gunakan dokumen audit terbaru:
> - [AUDIT_CATATAN.md](AUDIT_CATATAN.md) — temuan teknis (audit 17 Mei 2026, app v2.8.0)
> - [RENCANA_PERBAIKAN.md](RENCANA_PERBAIKAN.md) — rencana perbaikan & tracking task

# Action Items - DonaPOS Mobile

Berikut adalah daftar prioritas tindakan berdasarkan review teknis aplikasi DonaPOS Mobile v1.5.0.

---

## 🔴 CRITICAL - Must Fix Immediately

### 1. Security: Remove Hardcoded Credentials
**File:** `lib/utils_ui.dart` Line 19
```dart
// ❌ BEFORE (VULNERABLE)
if (pin == '0690' || pin == '2024') {
    Navigator.pop(context);
    onValid();
}

// ✅ AFTER (SECURE)
Future<bool> _validateOTP(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedOTP = prefs.getString('encrypted_otp');
    return PasswordHash.verify(pin, encryptedOTP);
}
```
**Estimasi:** 2 jam  
**Impact:** High - Security vulnerability

### 2. Fix Duplicate Import
**File:** `lib/screens/login_screen.dart` Line 8-9
```dart
// ❌ Remove duplicate
import 'package:donapos_mobile/config.dart';
import 'package:donapos_mobile/config.dart'; // DELETE THIS LINE
```
**Estimasi:** 5 menit  
**Impact:** Low - Code cleanliness

---

## 🟡 HIGH PRIORITY - Fix Within 1 Week

### 3. Add Memory Management
**File:** `lib/screens/pos_screen.dart`
```dart
// ❌ BEFORE (Memory Leak)
final _searchController = TextEditingController();
final _printerController = TextEditingController();

// ✅ AFTER (Proper cleanup)
@override
void dispose() {
    _searchController.dispose();
    _printerController.dispose();
    super.dispose();
}
```
**Estimasi:** 1 jam  
**Impact:** Medium - Memory efficiency

### 4. Implement Unit Tests
**Create:** `test/` directory dengan test files
```dart
// test/discount_engine_test.dart
test('should calculate fixed discount correctly', () {
    final discount = Discount(id: 1, name: 'Promo', type: 'fixed', amount: 10000);
    final result = applyDiscount(100000, discount);
    expect(result, 90000);
});

// test/pricing_engine_test.dart
test('should return correct price for dine-in', () {
    final price = getPriceForType(product, 'dinein', priceGroups);
    expect(price, 50000);
});
```
**Estimasi:** 2-3 hari  
**Impact:** High - Code reliability

### 5. Add Database Indexes
**File:** `lib/db_helper.dart`
```dart
Future _createDB(Database db, int version) async {
    // ... existing table creation ...
    
    // ✅ ADD INDEXES for performance
    await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
    await db.execute('CREATE INDEX idx_products_brand ON products(brand_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(created_at)');
    await db.execute('CREATE INDEX idx_transactions_synced ON transactions(synced)');
    await db.execute('CREATE INDEX idx_transaction_items_id ON transaction_items(transaction_id)');
}
```
**Estimasi:** 2 jam (+ testing)  
**Impact:** Medium - Query performance

### 6. Add Error Logging Service
**Create:** `lib/services/logger_service.dart`
```dart
class LoggerService {
    static final instance = LoggerService._();
    LoggerService._();
    
    void logError(String message, {dynamic error, StackTrace? stack}) {
        // Log to file
        // Send to crashlytics
        // Show in debug console
        print('ERROR: $message - $error');
        if (stack != null) print(stack);
    }
    
    void logInfo(String message) {
        print('INFO: $message');
    }
    
    void logSync(String action, {bool success = true}) {
        print('SYNC: $action - ${success ? "SUCCESS" : "FAILED"}');
    }
}
```
**Estimasi:** 4 jam  
**Impact:** High - Debugging & monitoring

---

## 🟢 MEDIUM PRIORITY - Fix Within 2 Weeks

### 7. Refactor Large File
**File:** `lib/screens/pos_screen.dart` (1,917 lines)

**Split into:**
```
lib/screens/pos/
├── pos_screen.dart          (main orchestrator, ~300 lines)
├── widgets/
│   ├── product_grid.dart    (product display logic)
│   ├── cart_list.dart       (cart management)
│   ├── payment_dialog.dart  (payment flow)
│   ├── receipt_preview.dart (receipt display)
│   └── category_filter.dart (category selection)
└── services/
    ├── pricing_service.dart (price calculation)
    └── discount_service.dart (discount logic)
```
**Estimasi:** 1-2 hari  
**Impact:** High - Code maintainability

### 8. Implement Retry Logic for API
**File:** `lib/api_service.dart`
```dart
Future<T> _retryRequest<T>(
    Future<T> Function() request, 
    {int maxRetries = 3}
) async {
    for (int i = 0; i < maxRetries; i++) {
        try {
            return await request();
        } catch (e) {
            if (i == maxRetries - 1) rethrow;
            await Future.delayed(Duration(seconds: pow(2, i).toInt()));
        }
    }
    throw Exception('Max retries reached');
}

// Usage
Future<List<Map<String, dynamic>>> syncProducts() async {
    return await _retryRequest(() async {
        final response = await http.get(...);
        // ... process response
    });
}
```
**Estimasi:** 4 jam  
**Impact:** Medium - Network reliability

### 9. Add Image Caching
**Update:** `pubspec.yaml`
```yaml
dependencies:
  cached_network_image: ^3.3.1
```

**Update:** Product image display
```dart
// ❌ BEFORE
Image.network(product.imageUrl)

// ✅ AFTER
CachedNetworkImage(
    imageUrl: product.imageUrl ?? '',
    placeholder: (context, url) => CircularProgressIndicator(),
    errorWidget: (context, url, error) => Icon(Icons.fastfood, size: 40),
    fit: BoxFit.cover,
)
```
**Estimasi:** 2 jam  
**Impact:** Medium - Performance

### 10. Implement Pagination
**File:** `lib/db_helper.dart`
```dart
Future<List<Map<String, dynamic>>> getAllProducts({
    int limit = 50, 
    int offset = 0,
    int? categoryId
}) async {
    final db = await instance.database;
    return await db.query(
        'products',
        where: categoryId != null ? 'category_id = ?' : null,
        whereArgs: categoryId != null ? [categoryId] : null,
        limit: limit,
        offset: offset,
        orderBy: 'name ASC'
    );
}
```
**Estimasi:** 3 jam  
**Impact:** Medium - Scalability

---

## 🔵 LOW PRIORITY - Nice to Have

### 11. Add Multi-Language Support
**Install:** `flutter_localizations`
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

**Create:** `lib/l10n/` directory
```
l10n/
├── app_en.arb  (English)
├── app_id.arb  (Indonesian)
└── app_zh.arb  (Chinese)
```
**Estimasi:** 2-3 hari  
**Impact:** Low - User experience (international)

### 12. Implement Barcode Scanner
**Add:** `pubspec.yaml`
```yaml
dependencies:
  mobile_scanner: ^3.5.5
```
**Estimasi:** 1 hari  
**Impact:** Low - Convenience feature

### 13. Add Dark/Light Theme Toggle
**File:** `lib/main.dart`
```dart
class MyApp extends StatefulWidget {
    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(), // Already using dark
            themeMode: _themeMode, // User preference
        );
    }
}
```
**Estimasi:** 4 jam  
**Impact:** Low - User preference

---

## 📊 Progress Tracking

### Sprint 1 (Week 1)
- [ ] Item #1: Remove hardcoded credentials
- [ ] Item #2: Fix duplicate import
- [ ] Item #3: Add memory management
- [ ] Item #5: Add database indexes
- [ ] Item #6: Error logging service

**Target Completion:** 7 hari  
**Estimated Effort:** 16 hours

### Sprint 2 (Week 2-3)
- [ ] Item #4: Unit tests (50% coverage)
- [ ] Item #7: Refactor pos_screen.dart
- [ ] Item #8: API retry logic
- [ ] Item #9: Image caching
- [ ] Item #10: Pagination

**Target Completion:** 14 hari  
**Estimated Effort:** 32 hours

### Sprint 3 (Future Backlog)
- [ ] Item #11: Multi-language
- [ ] Item #12: Barcode scanner
- [ ] Item #13: Theme toggle
- [ ] Advanced features (split payment, loyalty, etc)

---

## ✅ Definition of Done

Setiap item dianggap selesai jika:
1. ✅ Code changes implemented
2. ✅ Code reviewed oleh senior developer
3. ✅ Unit tests passed (jika applicable)
4. ✅ Manual testing completed
5. ✅ Documentation updated
6. ✅ No new linting errors
7. ✅ Performance benchmarks met

---

## 📈 Success Metrics

**Target Improvements:**
- Security Score: 6/10 → 9/10
- Test Coverage: 0% → 70%
- Code Quality: 8/10 → 9/10
- Performance: 8/10 → 9.5/10

**KPIs to Track:**
- App crash rate
- API request success rate
- Average transaction processing time
- User satisfaction score

---

**Last Updated:** 22 Januari 2026  
**Review berdasarkan:** DonaPOS Mobile v1.5.0 (Build 18)
