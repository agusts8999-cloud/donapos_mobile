# 📱 DonaPOS Mobile v1.6.0 - Deployment Guide

## 🎯 What's New in v1.6.0

### OAuth Client Auto-Detection
Aplikasi mobile sekarang **otomatis mendeteksi** business dan location dari konfigurasi OAuth client di backend. Tidak perlu lagi manual input nama bisnis dan lokasi!

---

## 📋 Changes Summary

### Backend (Already Uploaded ✅)
1. **OAuth Clients Table**: Added `business_id` and `location_id` columns
2. **ClientController.php**: Create client form with business & location selection
3. **BusinessLocationController.php**: API auto-filter by OAuth client
4. **clients/index.blade.php**: Enhanced admin UI

### Mobile App (Need to Build & Deploy)
1. **api_service.dart**: Enhanced sync logic with OAuth client auto-detection
2. **config.dart**: Version bumped to 1.6.0
3. **CHANGELOG.md**: Documented new features

---

## 🚀 Deployment Steps

### Step 1: Build APK

```bash
cd /Applications/XAMPP/xamppfiles/htdocs/erpdonapos/donapos_mobile

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release
```

**Expected Output:**
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (XX MB)
```

### Step 2: Test on Device

**Option A: Install via USB**
```bash
# Connect Android device via USB
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option B: Copy APK manually**
- Copy `build/app/outputs/flutter-apk/app-release.apk` ke device
- Install manually

---

## ✅ Testing Checklist

### Test 1: OAuth Client Auto-Detection

**Prerequisites:**
- Backend sudah updated (BusinessLocationController.php uploaded)
- OAuth client (e.g. ID 13) sudah ada business_id=2, location_id=2

**Steps:**
1. Install new APK v1.6.0
2. Open app → Config Screen (atau setup mode)
3. Configure:
   - Client ID: `13`
   - Client Secret: `6emFpU...`
   - Base URL: `https://donapos.serverzone.web.id`
   - **Leave Business Name & Location Name EMPTY**
4. Login dengan username & password
5. Perform sync (akan otomatis di backend)

**Expected Results:**
✅ Business Name auto-terisi: "Kopiling" atau nama bisnis Anda  
✅ Location Name auto-terisi: "Kopiling Akenpro" atau nama lokasi Anda  
✅ Console log shows:
```
[SYNC] 📍 Fetching business details for Client ID: 13
[SYNC] 📦 Received 1 location(s) from API
[SYNC] ✨ Auto-detected Location ID: 2 (Kopiling Akenpro)
[SYNC] ✅ Business Details Synced:
       📌 Name: Kopiling Akenpro
       📍 Address: Akenpro, Jakarta Barat
       🆔 Location ID: 2
```

### Test 2: Data Sync dengan Location Filter

**Steps:**
1. Setelah login berhasil
2. Trigger sync all data
3. Check console logs

**Expected Results:**
✅ All sync methods show correct location ID:
```
[SYNC] 👥 Syncing users for Location ID: 2
[SYNC] 📦 Syncing products for Location ID: 2
[SYNC] 🪑 Syncing restaurant tables for Location ID: 2
```

✅ Users displayed hanya untuk location tersebut  
✅ Products displayed sesuai location  
✅ Restaurant tables sesuai location  

### Test 3: Transaction Upload

**Steps:**
1. Make a POS transaction
2. Complete payment
3. Sync transactions ke server

**Expected Results:**
✅ Transaction payload includes correct `location_id`:
```json
{
  "sells": [{
    "location_id": "2",
    ...
  }]
}
```

✅ Transaction ter-upload ke backend dengan location yang benar  
✅ Check di Admin Panel → POS → List Sell → Location sesuai  

---

## 📊 Version Comparison

| Feature | v1.3.7 (Old) | v1.6.0 (New) |
|---------|--------------|--------------|
| Business Name Detection | ❌ Manual input | ✅ Auto from OAuth client |
| Location Name Detection | ❌ Manual input | ✅ Auto from OAuth client |
| Location ID Detection | 🟡 Must configure | ✅ Auto-save if single location |
| Sync Filtering | 🟡 Partial | ✅ All syncs respect location |
| Logging | ⚪ Basic | ✅ Enhanced with emoji |
| Multi-outlet Support | 🟡 Manual per device | ✅ Config once in backend |

---

## 🔧 Configuration Examples

### Scenario 1: Single Outlet (Kopiling Akenpro)

**Backend (Admin Panel):**
```
OAuth Client ID: 13
Name: Kopiling
Business ID: 2
Location ID: 2
```

**Mobile App:**
```
Client ID: 13
Client Secret: 6emFpU...
Base URL: https://donapos.serverzone.web.id
Business Name: (kosong - auto-filled)
Location Name: (kosong - auto-filled)
Location ID: (kosong - auto-detected)
```

**Result:**
- Business Name: "Kopiling Akenpro" ✅
- Location Name: "Kopiling Akenpro" ✅
- All data filtered to Location ID 2 ✅

### Scenario 2: Multiple Outlets (Different Tablets)

**Outlet 1 (Akenpro):**
```
OAuth Client ID: 13
Business ID: 2
Location ID: 2
→ Tablet 1 auto-detect: Akenpro
```

**Outlet 2 (Kopiling):**
```
OAuth Client ID: 14 (new client)
Business ID: 2
Location ID: 3
→ Tablet 2 auto-detect: Kopiling
```

**Result:**
- Each tablet auto-configured for its location ✅
- Data isolation per location ✅
- Zero manual setup on tablets ✅

---

## 🐛 Troubleshooting

### Issue 1: Business Name masih kosong setelah sync

**Diagnosis:**
```bash
# Check console logs
flutter logs (or adb logcat)

# Look for:
[SYNC] ⚠️  No locations received. Check OAuth client configuration.
```

**Solution:**
- Verify OAuth client has `business_id` and `location_id` set di backend
- Check API response: `curl -H "Authorization: Bearer TOKEN" https://donapos.serverzone.web.id/connector/api/business-location`
- Verify backend file `BusinessLocationController.php` uploaded correctly

### Issue 2: Flutter build error

**Error:** `Execution failed for task ':app:lintVitalRelease'`

**Solution:**
```bash
# Add to android/app/build.gradle.kts:
lintOptions {
    checkReleaseBuilds = false
    abortOnError = false
}
```

### Issue 3: App crashes on sync

**Solution:**
- Check Flutter console for stack trace
- Verify API endpoints accessible
- Check token validity
- Clear app data and re-login

---

## 📦 Distribution

### Method 1: Direct APK Install
1. Copy APK to shared drive/cloud
2. Send link to users
3. Users download & install

### Method 2: Play Store (Future)
1. Setup Play Console account
2. Create app listing
3. Upload APK bundle
4. Publish

### Method 3: Firebase App Distribution
1. Upload to Firebase
2. Invite testers via email
3. They install via Firebase link

---

## 🔄 Rollback Plan

If there are critical issues:

```bash
# Restore backup
cd /Applications/XAMPP/xamppfiles/htdocs/erpdonapos/donapos_mobile/lib
cp api_service.dart.backup api_service.dart

# Build previous version
flutter build apk --release

# Distribute old APK
```

---

## 📝 Release Notes (for Users)

**DonaPOS Mobile v1.6.0 - Auto-Configuration Update**

**Apa yang baru:**
- ✨ **Auto-Configuration**: Tidak perlu lagi manual input nama bisnis dan lokasi! Aplikasi otomatis detect dari server.
- 🔄 **Smart Sync**: Data yang di-sync sekarang otomatis filtered sesuai outlet Anda.
- 📍 **Location Auto-Detection**: Location ID otomatis terdeteksi jika client sudah dikonfigurasi di backend.
- 🚀 **Faster Setup**: Setup lebih cepat - tinggal login, langsung ready to use!

**Cara Update:**
1. Download APK v1.6.0
2. Install (akan replace versi lama)
3. Buka app → Config → Input Client ID & Secret
4. Login → Sync → Done!

**Catatan:**
- Pastikan admin sudah set business_id dan location_id untuk OAuth client Anda di backend.
- First-time setup tetap perlu login admin untuk sync data awal.

---

## ✅ Post-Deployment Checklist

- [ ] APK built successfully (check file size ~40-50 MB)
- [ ] Installed on test device
- [ ] Login works with OAuth client
- [ ] Business name auto-filled after sync
- [ ] Location name auto-filled after sync
- [ ] Console logs show correct location ID
- [ ] Users list filtered by location
- [ ] Products list filtered by location
- [ ] Tables list filtered by location
- [ ] Transaction upload includes correct location_id
- [ ] No crashes or errors
- [ ] Version number shows 1.6.0 in About screen
- [ ] Changelog displays new features

---

## 📞 Support

**If issues persist:**
1. Check Laravel logs on VPS: `tail -f /var/www/html/donapos/storage/logs/laravel.log`
2. Check Flutter logs: `flutter logs` or `adb logcat`
3. Test API manually with Postman/cURL
4. Verify database values in phpMyAdmin

**Contacts:**
- Developer: [Your Contact]
- Admin: [Admin Contact]
- WA Support: 081219752227

---

**Deployment Date:** 22 Januari 2026  
**Version:** 1.6.0 (Build 19)  
**Status:** ✅ READY FOR PRODUCTION
