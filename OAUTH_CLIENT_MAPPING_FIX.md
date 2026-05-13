# Fix: OAuth Client tidak memiliki Business ID dan Location ID

## 🔴 Problem
OAuth Client (seperti ID 13 "Kopiling") tidak memiliki mapping ke `business_id` dan `location_id`, sehingga aplikasi mobile tidak bisa otomatis mendapatkan nama bisnis dan lokasi setelah login.

## ✅ Solution Options

### **Option 1: Add Columns to oauth_clients Table (RECOMMENDED)**

#### 1.1 Migration SQL
```sql
-- File: database/migrations/xxxx_add_business_location_to_oauth_clients.php

ALTER TABLE `oauth_clients` 
ADD COLUMN `business_id` INT(10) UNSIGNED NULL AFTER `name`,
ADD COLUMN `location_id` INT(10) UNSIGNED NULL AFTER `business_id`,
ADD INDEX `idx_business` (`business_id`),
ADD INDEX `idx_location` (`location_id`);

-- Update existing clients
UPDATE `oauth_clients` 
SET 
    `business_id` = 2,  -- Kopiling business
    `location_id` = 2   -- Kopiling Akenpro location
WHERE `id` = 13;

UPDATE `oauth_clients`
SET
    `business_id` = 5,
    `location_id` = 1
WHERE `id` = 12 AND `name` = 'donapos1';
```

#### 1.2 Update Backend API Endpoint

**File:** `Modules/Connector/Http/Controllers/Api/BusinessLocationController.php`

```php
public function index(Request $request)
{
    try {
        $user = $request->user();
        
        // NEW: Check if request has client_id (from OAuth token)
        $clientId = $request->input('client_id') ?? $request->user()->token()->client_id ?? null;
        
        $query = BusinessLocation::with(['invoice_scheme', 'invoice_layout']);
        
        // Filter by OAuth Client's Location (if configured)
        if ($clientId) {
            $client = \DB::table('oauth_clients')->where('id', $clientId)->first();
            if ($client && $client->location_id) {
                $query->where('id', $client->location_id);
            }
        }
        
        // Fallback: Show all if no specific location tied
        $locations = $query->select([
            'id',
            'business_id', 
            'location_id',
            'name',
            'landmark',
            'city',
            'state',
            'country',
            'zip_code',
            'mobile',
            'invoice_scheme_id',
            'invoice_layout_id'
        ])->get();

        return response()->json([
            'success' => true,
            'data' => $locations
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => $e->getMessage()
        ], 500);
    }
}
```

#### 1.3 Update Mobile App Auto-Detection

**File:** `lib/api_service.dart` - Update `syncBusinessDetails()`

```dart
Future<void> syncBusinessDetails() async {
    final baseUrl = await getBaseUrl();
    final locationId = await getLocationId();
    final clientId = await getClientId();
    final headers = await _getHeaders();
    if (headers['Authorization'] == 'Bearer null') return;
    
    try {
        // Option A: Send client_id to let backend filter
        final response = await http.get(
            Uri.parse('$baseUrl/connector/api/business-location?client_id=$clientId'),
            headers: headers
        );
        
        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List locations = data['data'];
            
            // NEW LOGIC: Priority untuk location match
            Map<String, dynamic>? myLoc;
            
            // 1. Try exact match dengan saved locationId
            if (locationId.isNotEmpty) {
                myLoc = locations.firstWhere(
                    (l) => l['id'].toString() == locationId || 
                           l['location_id']?.toString() == locationId,
                    orElse: () => null
                );
            }
            
            // 2. If only 1 location returned (filtered by client), use it
            if (myLoc == null && locations.length == 1) {
                myLoc = locations.first;
                
                // AUTO-SAVE detected location ID
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('location_id', myLoc['id'].toString());
                print('[SYNC] Auto-detected Location ID: ${myLoc['id']}');
            }
            
            // 3. Otherwise fallback to first if locationId not set
            if (myLoc == null && locations.isNotEmpty) {
                myLoc = locations.first;
            }
            
            if (myLoc != null) {
                final prefs = await SharedPreferences.getInstance();
                
                // Save Business & Location Names
                await prefs.setString('business_name', myLoc['name'] ?? 'DonaPOS');
                await prefs.setString('location_name', myLoc['name'] ?? 'Outlet');
                
                // Address formatting
                String address = "${myLoc['landmark'] ?? ''}, ${myLoc['city'] ?? ''}".trim();
                if (address.startsWith(',')) address = address.substring(1).trim();
                if (address.endsWith(',')) address = address.substring(0, address.length - 1).trim();
                if (address.isEmpty) address = "Jakarta";

                await prefs.setString('business_address', address);
                await prefs.setString('business_mobile', myLoc['mobile'] ?? '081219752227');
                
                // Invoice Layout
                if (myLoc['invoice_layout'] != null) {
                    final layout = myLoc['invoice_layout'];
                    await prefs.setString('lbl_subtotal', layout['sub_total_label'] ?? 'Subtotal');
                    await prefs.setString('lbl_discount', layout['discount_label'] ?? 'Diskon');
                    await prefs.setString('lbl_tax', layout['tax_label'] ?? 'Pajak');
                    await prefs.setString('lbl_total', layout['total_label'] ?? 'TOTAL');
                    await prefs.setString('lbl_return', layout['change_return_label'] ?? 'Kembalian');
                    await prefs.setString('footer_text', layout['footer_text'] ?? 'Terima Kasih');
                }

                // Invoice Prefix
                if (myLoc['invoice_scheme'] != null) {
                    final scheme = myLoc['invoice_scheme'];
                    await prefs.setString('invoice_prefix', scheme['prefix'] ?? 'MBL');
                }

                print('✓ Business Details Synced: ${myLoc['name']}');
                print('✓ Location: ${address}');
            } else {
                print('⚠️  Warning: No location data found!');
            }
        }
    } catch (e) {
        print('❌ Sync Business Error: $e');
    }
}
```

---

### **Option 2: Manual Configuration per Device (Current Workaround)**

Jika tidak ingin modifikasi database/backend, user harus manual input di Config Screen:

1. Buka **Config Screen** (tombol gear/setup)
2. Input manual:
   - Business Name: `Kopiling`
   - Location Name: `Akenpro`
   - Location ID: `2`

Tapi ini tidak scalable jika banyak outlet.

---

## 🔧 Implementation Steps (Option 1)

### Step 1: Database Migration
```bash
# Di folder Laravel ERP
php artisan make:migration add_business_location_to_oauth_clients
```

```php
// File: database/migrations/xxxx_add_business_location_to_oauth_clients.php
public function up()
{
    Schema::table('oauth_clients', function (Blueprint $table) {
        $table->unsignedInteger('business_id')->nullable()->after('name');
        $table->unsignedInteger('location_id')->nullable()->after('business_id');
        $table->index('business_id');
        $table->index('location_id');
    });
}

public function down()
{
    Schema::table('oauth_clients', function (Blueprint $table) {
        $table->dropColumn(['business_id', 'location_id']);
    });
}
```

```bash
php artisan migrate
```

### Step 2: Seed Data (Update Existing Clients)

```sql
-- Kopiling Client
UPDATE oauth_clients 
SET business_id = 2, location_id = 2 
WHERE id = 13;

-- DonaPOS1 Client  
UPDATE oauth_clients
SET business_id = 5, location_id = 1
WHERE id = 12;
```

### Step 3: Update API Backend

Update `BusinessLocationController@index` seperti code di atas.

### Step 4: Update Mobile App

Replace `syncBusinessDetails()` di `api_service.dart` dengan version yang sudah saya berikan di atas.

### Step 5: Update Export OAuth CSV

**File:** `public/export_oauth.php` (atau file yang generate CSV untuk OAuth)

```php
// NEW: Include business_id and location_id in CSV export
$sql = "SELECT 
    id, 
    name, 
    secret,
    business_id,
    location_id
FROM oauth_clients 
WHERE revoked = 0 
ORDER BY id";

// CSV Header
fputcsv($output, ['ID', 'Name', 'Secret', 'BusinessID', 'LocationID']);

// CSV Data rows
foreach ($clients as $client) {
    fputcsv($output, [
        $client->id,
        $client->name,
        $client->secret,
        $client->business_id ?? '',
        $client->location_id ?? ''
    ]);
}
```

---

## ✅ Benefits

1. **Auto-detection** - Aplikasi otomatis detect business/location dari OAuth client
2. **Scalable** - Mudah setup multi-outlet dengan client berbeda
3. **Zero Config** - User tidak perlu manual input nama bisnis/lokasi
4. **Centralized** - Semua konfigurasi di backend, mudah management

---

## 🧪 Testing

1. Login dengan Client ID 13 (Kopiling)
2. Check apakah nama bisnis & lokasi otomatis terisi "Kopiling - Akenpro"
3. Verify di Login Screen header menampilkan nama yang benar
4. Check struk printer apakah menampilkan nama bisnis yang benar

---

## 📋 Rollback Plan

Jika ada masalah:
```sql
ALTER TABLE oauth_clients
DROP COLUMN business_id,
DROP COLUMN location_id;
```

Dan revert mobile app ke version sebelumnya (git reset).
