class AppConfig {
  static const String appName = 'DonaPOS_Fnb_Plus';
  static const String appVersion = '2.7.9';
  static const String buildNumber = '10233';
  
  static bool isTrainingMode = false;

  static const List<Map<String, dynamic>> changelog = [
    {
      'version': '2.7.9',
      'date': '2026-05-13',
      'changes': [
        'Fix: Transaction-Safe BT Hard-Swap (Prevents mixed receipts)',
        'Fix: Focused Test Print (Always connects to current role printer)',
        'UI: Scrollable Kitchen settings for small tablets',
        'Feature: Printer Alias (Bind role to MAC address)',
        'Feature: Manual "PUTUSKAN" button in Kitchen settings',
        'UI: Distinct Green/Orange roles for Cashier vs Kitchen printers',
        'Fix: Automatic BT connection swap for dual-printer setups',
        'Feature: "TEST PRINT" button in Kitchen Printer settings',
        'UI: Added "PRINTER DAPUR" option to Cashier Menu',
        'Fix: Kitchen Printer routing (LAN/BT/USB support)',
        'Fix: Admin Login choice (Dashboard vs Cashier) now works offline',
        'Performance: Optimized Offline-First Login (Instant Access)',
        'Sync: Background background authentication for Staff Login',
        'Stability: Reduced API timeouts for faster server failure detection',
        'Cross-Platform: Windows OS support preparation'
      ]
    },
    {
      'version': '2.7.8',
      'date': '2026-02-22',
      'changes': [
        'UI: Responsive Scaling System (.sc & .sp units)',
        'UI: Full tablet optimization for POS elements',
        'UI: Scaled receipt preview, dialogs, and navigation',
        'Build: Updated app naming to DonaPOS_Fnb_Plus'
      ]
    },
    {
      'version': '2.7.7',
      'date': '2026-02-14',
      'changes': [
        'Feature: Demo Mode Upgrade (Offline First & Custom Data Snapshot)',
        'Data: Enhanced Demo Dataset (Tashia Admin, Products with Images)',
        'UX: Offline Restriction Indicators & Dialogs',
        'Config: "Use Current Data" toggle for realistic training simulations'
      ]
    },
    {
      'version': '2.7.6',
      'date': '2026-02-13',
      'changes': [
        'Bugfix: Attendance Sync Logic (Handle duplicate clock-in errors gracefully)',
        'Build: Stability improvements for attendance synchronization',
      ]
    },
    {
      'version': '2.7.5',
      'date': '2026-02-13',
      'changes': [
        'Critical Fix: Cashier Identity / Sales Attribution Logic',
        'Config: Enforced Admin Defaults (Kitchen OFF, Receipt OFF, Post ON)',
        'Bugfix: Product Label Settings Infinite Loading',
        'Build: Updated dependencies & stabilization'
      ]
    },
    {
      'version': '2.7.4',
      'date': '2026-02-12',
      'changes': [
        'Bugfix: Locked Cashier Attendance logic after migration/sync',
        'Feature: Attendance Requirement toggle in Admin Dashboard',
        'Security: Level Admin Auto-Auth for background transaction posting',
        'Settings: Consolidated Label Printer settings in Label Manager',
        'Bugfix: Resolved double-trigger event on label product switch',
      ]
    },
    {
      'version': '2.7.2',
      'date': '2026-02-12',
      'changes': [
        'UX: Optimized synchronization indicator to perform quick sales-only upload',
        'Feature: Toggle visibility for BILL button in header (Default OFF)',
        'Feature: Toggle visibility for KITCHEN button in header (Default ON)',
        'Admin: New System Data toggles for UI elements',
      ]
    },
    {
      'version': '2.7.1',
      'date': '2026-02-12',
      'changes': [
        'Feature: Configurable Auto-Posting (On/Off toggle)',
        'Feature: Adjustable synchronization interval in minutes',
        'Backend: Dynamic SyncService restart on settings change',
      ]
    },
    {
      'version': '2.7.0',
      'date': '2026-02-12',
      'changes': [
        'Sync: Reliable Auto-Posting (Singleton Service & Lock)',
        'Sync: Instant UI refresh after transaction posting',
        'Stability: Pre-emptive server authentication on login',
        'Fix: Prevented duplicate sync tasks during active transactions',
      ]
    },
    {
      'version': '2.6.6',
      'date': '2026-02-11',
      'changes': [
        'Stability: Disabled Impeller for Emulator & Old Hardware compatibility',
        'Performance: Optimized RAM & VM Heap for low-end tablets',
        'UI: Smoother Splash transitions & updated versioning',
        'Fix: Background Sync ANR prevention',
      ]
    },
    {
      'version': '2.6.4',
      'date': '2026-02-06',
      'changes': [
        'Fitur: Produk Unggulan & Kategori Favorit',
        'UI: Ikon Bintang pada Sidebar Kategori',
        'UI: Sinkronisasi Produk Favorit dari Server',
        'Fix: Filter Produk Favorit & DB Migration (v41)',
        'Fitur: Manajemen Migrasi Database (Migrasi vs Reset)',
        'Debug: Log Migrasi Database Real-time',
      ]
    },
    {
      'version': '2.6.3',
      'date': '2026-02-06',
      'changes': [
        'UI: New Empty State Visualization for Empty Categories',
        'UI: Friendly "No Products Found" illustration',
      ]
    },
    {
      'version': '2.6.1',
      'date': '2026-02-03',
      'changes': [
        'Sync: Compacted Synchronize Center UI for better tablet fit (Removed dividers, reduced vertical padding)',
      ]
    },
    {
      'version': '2.6.0',
      'date': '2026-02-03',
      'changes': [
        'Reporting: New Expense Report (Laporan Biaya) with Date Filtering & Printing',
        'Database: Added Auto-Deduplication Logic for locally created products during sync',
        'Stability: Improved Reset Sales & Hard Reset logic (Cleans modal awal & cashier session)',
        'UX: Revamped Manual Product Manager (Horizontal Layout & Hidden Queues)',
        'Sync: Enhanced data integrity and automatic cashier accountability'
      ]
    },
    {
      'version': '2.5.14',
      'date': '2026-02-01',
      'changes': [
        'Payment: Grouped Items by Category in Payment Screen',
        'Feature: Select All per Category for easier Split Bill',
        'UX: Improved visual hierarchy in Payment Cart list'
      ]
    },
    {
      'version': '2.5.13',
      'date': '2026-02-01',
      'changes': [
        'Payment: Enriched Payment Methods Grid (4 Columns)',
        'UI: Enlarged Payment Selection Area for Better Visibility',
        'UX: Improved Split Payment Layout Balance',
        'System: Build Release Compatibility Fixes',
        'Sync: Modifier & Topping Synchronization Fixes'
      ]
    },
    {
      'version': '2.5.9',
      'date': '2026-01-31',
      'changes': [
        'Fix: Cashier ID Tracking & Accountability (Synced to ERP created_by)',
        'Database: Schema Upgrade v32 (Recovery & Stability Migration)',
        'Fix: SQL Exception on Payment (Missing Discount Column in details)',
        'Fix: Undefined Database Helper Methods for Customers & Groups',
        'App: Standardized Sync Payload for Staff Attribution'
      ]
    },
    {
      'version': '2.5.5',
      'date': '2026-01-30',
      'changes': [
        'UI: New Animated Splash Screen with Rotating Logo',
        'UI: Premium Global Loader using Donapos Branding',
        'Refactoring: Centralized POS Pricing & Dynamic Price Groups',
        'Sync: Restored all sync features in Admin & Cashier menus',
        'UX: Improved visual transitions and branding across app'
      ]
    },
    {
      'version': '2.2.0',

      'date': '2026-01-29',
      'changes': [
        'Security: Dynamic OTP System (Challenge-Response) untuk fitur sensitif',
        'Localization: Full Support Bahasa Indonesia & English',
        'Feature: Instant Language Switcher di POS Header',
        'App: New "OTP Vendor" app for Owners',
        'UI: About Screen with Dynamic Changelog & Versioning'
      ]
    },
    {
      'version': '2.1.0',
      'date': '2026-01-27',
      'changes': [
        'UX: Pindahkan Tombol Posting ke Menu Kasir',
        'Performance: Delta Sync (Download Data Lebih Cepat)',
        'Performance: Batch Upload (Upload Transaksi Lebih Cepat & Stabil)',
        'Optimization: Paginasi Data Produk & Kontak',
        'System: Auto-retry mechanism for sync'
      ]
    },
    {
      'version': '1.8.0',
      'date': '2026-01-24',
      'changes': [
        'POS Header: Added Real-time Clock & Transaction ID display',
        'Reporting: Pro Grid Tables with standard Currency (Rp) formatting',
        'Reporting: Standardized Date format to dd/MM/yyyy',
        'Feature: Held Orders List (Call back transactions without tables)',
        'Cashier: Initial Cash (Modal Awal) flow for session opening',
        'Attendance: Fingerprint-style Clock In/Out system',
        'Attendance: Automatic slip printing for staff attendance',
        'Attendance: Working hours/duration calculation (e.g. 8h 30m)',
        'Attendance: Historical Attendance Report with Date Range Filter',
        'Optimization: Forced Landscape mode & Tablet 7" layout improvements'
      ]
    },
    {
      'version': '1.7.0',
      'date': '2026-01-24',
      'changes': [
        'Dashboard: Metro UI Admin Dashboard overhaul',
        'UI: Interactive Sale Type in Header (Clickable)',
        'UI: Refined Payment Dialog and Tabs',
        'Feature: Reset Penjualan option in Admin menu',
        'Sync: "Posting ke Cloud" with secure loader animation',
        'Sync: Optimized Sync Center menu items',
        'Logic: Default Dine-In and automatic flow improvement',
        'Fix: Always visible report print buttons'
      ]
    },
    {
      'version': '1.6.0',
      'date': '2026-01-22',
      'changes': [
        'New: OAuth Client Auto-Detection',
        'System: Automatic business & location detection from OAuth client',
        'System: Zero manual configuration - nama bisnis & lokasi auto-terisi',
        'Sync: All data syncs now respect business_id & location_id from OAuth client',
        'Sync: Improved logging dengan emoji untuk easier debugging',
        'Backend: Full integration dengan OAuth client configuration'
      ]
    },
    {
      'version': '1.3.7',
      'date': '2026-01-22',
      'changes': [
        'New: Immersive Mode (Layar Utuh)',
        'System: Status bar & Navigation bar hidden (Kiosk Mode)',
        'System: Auto-keyboard focus handling'
      ]
    },
    {
      'version': '1.3.6',
      'date': '2026-01-22',
      'changes': [
        'New: Always On Display',
        'System: Tablet won\'t sleep while app is active'
      ]
    },
    {
      'version': '1.3.5',
      'date': '2026-01-22',
      'changes': [
        'Fix: VPS Connectivity (Internet Permissions)',
        'New: Info Back Office & Help Buttons on Setup',
        'Sync: Improved Transaction Payload Format',
        'Z-Report: Graceful "No Records Found" handling'
      ]
    },
    {
      'version': '1.3.4',
      'date': '2026-01-21',
      'changes': [
        'New: Receipt Simulation Dialog (Preview)',
        'New: Flexible Print Options (1x, 2x, None)',
        'UI: Large primary print button for faster workflow',
        'UI: Cleaned up Info Diskon & Data view'
      ]
    },
    {
      'version': '1.3.3',
      'date': '2026-01-21',
      'changes': [
        'Critical Discount Sync Fix (Server-side date bypass)',
        'Enhanced Error Logging for Data Sync',
        'Improved Number Parser for ERP Strings',
        'Fixed Location ID Mismatch during Sync'
      ]
    },
    {
      'version': '1.3.1',
      'date': '2026-01-21',
      'changes': [
        'Advanced Discount Accuracy Engine (v2)',
        'Support Brand-based & Category-based Discounts Sync',
        'Selling Price Group (SPG) Discount Filtering',
        'Admin Dashboard: New "Sync Seluruh Data" Button',
        'Database Schema Upgrade v9 (Accuracy Improvements)',
        'Bugfix: Icons & Discount Sync mismatch'
      ]
    },
    {
      'version': '1.3.0',
      'date': '2026-01-21',
      'changes': [
        'Multi Price Groups (Retail, Wholesale, etc) Sync',
        'Auto Price Switching based on Order Type (Dine In/Online/Take Away)',
        'Advanced Discount Engine (Fixed/Percentage, per Item/Total)',
        'Promo Badge Indicator pada Produk Diskon',
        'Tax (Pajak) Calculation & Reporting',
        'Detailed Receipt Breakdown (Subtotal, Diskon, Tax)',
        'Database Schema Update v6 (Taxes & Discounts Support)'
      ]
    },
    {
      'version': '1.2.0',
      'date': '2026-01-21',
      'changes': [
        'Metro UI Overhaul (Dark Theme, Flat Design)',
        'Login & User Select dengan Live Tiles',
        'POS Grid Layout dengan Interaction Modes (+ - x)',
        'Smart Quick Cash dengan Logika Additive/Replace',
        'Format Nominal Uang Otomatis (Thousand Separator)',
        'Tampilan Pembayaran Full Black Metro Style',
        'Optimasi Layout Tombol Bayar & Navigasi'
      ]
    },
    {
      'version': '1.1.0',
      'date': '2026-01-20',
      'changes': [
        'Fitur Setup Awal (Download Data dari ERP)',
        'Login menggunakan PIN',
        'Sinkronisasi Kategori Produk',
        'Tampilan Grid Produk dengan Gambar',
        'Filter Produk per Kategori',
        'Quick Cash Buttons (20k, 50k, 100k)',
        'Auto-connect Printer Tersimpan',
        'Desain Struk Baru (Centered Logo)',
        'Menu About & Changelog'
      ]
    },
    {
      'version': '1.0.0',
      'date': '2026-01-20',
      'changes': [
        'Rilis Perdana (MVP)',
        'Transaksi Offline-First',
        '3 Mode Harga (Dine In, Take Away, Online)',
        'Sync Transaksi manual ke ERP',
        'Support Bluetooth Thermal Printer',
        'Database SQLite Lokal'
      ]
    }
  ];
}
