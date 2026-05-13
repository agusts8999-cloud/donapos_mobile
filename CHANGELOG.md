# Changelog

## [2.7.5] - 2026-02-13
### Authentication & Configuration
- **Critical Fix**: Resolved cashier identity mismatch by enforcing explicit payload attributes.
- **Config**: Enforced strict Admin Defaults (Kitchen OFF, Auto Print Receipt OFF, Attendance ON).
- **Bugfix**: Resolved infinite loading loop in Product Label Settings.
- **System**: Updated build number and dependencies.

## [2.6.5] - 2026-02-07
### iCod Printer Integration
- **Direct SDK Support**: Implemented native integration for iCod hardware-based printers (USB and Serial).
- **Printer-Agnostic Reporting**: Refactored `ReportDialog` printing logic to support both Bluetooth and iCod printers using unified helper methods (`_printRawLine`, `_printLRLine`).
- **Unified Settings**: Added iCod configuration (USB/Serial, Path, Baud Rate) langsung ke dalam Dialog Pengaturan Printer.
- **Reporting Enhancements**: Mengupdate semua tipe laporan (Z-Report, Ringkasan Produk, Absensi, Pengeluaran, dll) untuk mendukung pencetakan iCod kecepatan tinggi dan potong kertas otomatis.

## [2.6.2] - 2026-02-06
### POS & Pricing Consistency
- **Sync Price Reliability**: Fixed race conditions during price group & customer selection to ensure product grid and cart totals always match.
- **Auto-Refresh Cart**: Cart items now automatically update their prices when switching sale types (Dine In, Gofood, etc.) or customer price groups mid-transaction.
- **Tranparency**: Added item-level discount display in the cart panel (Net Price) to match the visual expectations from the product grid.

### Detailed Reporting
- **Payment Breakdown**: Revamped "Shift Report" and "Z-Report" to dynamically group and display totals for ALL payment methods (e.g., OVO, GoPay, Card, Cash) instead of basic groupings.
- **Reporting UI**: Integrated the detailed rincian pembayaran section directly into the report dialog screens.


## [2.5.15] - 2026-02-01
### Features & UX Improvements
- **Hold & Resume Enhancements**:
  - **Transaction Preservation**: Resuming a held transaction now correctly restores ALL data, including:
    - Pax (Number of Guests).
    - Customer Name and Detail.
    - Assigned Waiter.
    - Product Modifiers/Toppings.
  - **Notes Support**: Added ability to input a **Hold Note** (e.g., customer name, "waiting for friend") when holding a transaction.
  - **Quick Hold**: If note is left empty, a 4-digit random code is automatically generated for quick ID.
  - **Hold Receipt**: Added option to Print Hold Receipt immediately after holding (configurable in Admin Settings).
  - **UI Update**: Held Orders list now prominently displays the Note/Code in red for fast identification.
- **Bill Preview**:
  - Added **"BILL" Button** (yellow icon) in POS header.
  - Allows waiters/cashiers to show a **Receipt Simulation** (Preview) to customers before finalizing payment.
  - Preview hides payment method details (since it's not paid yet) but shows full order details including tax/service.
- **Receipt & Print Perfection**:
  - **Information Completeness**: Physical prints and Previews now include:
    - Table Name & Pax Count.
    - Waiter Name.
    - Detailed Product Modifiers (Toppings) under each item.
    - Item Notes.
  - **Layout Fixes**: Removed duplicate cashier lines and improved header alignment.

## [2.5.14] - 2026-02-01
### Features
- **Payment Dialog**:
  - **Category Grouping**: Shopping cart items in payment dialog are now grouped by category.
  - **Category Selection**: Added ability to check/uncheck entire categories for quicker split bill selection.

## [2.5.13] - 2026-02-01
### Interface Improvements
- **POS Payment Dialog**:
  - **Enhanced Layout**: Middle column redesigned to prioritize payment method visibility.
  - **Grid View**: Payment methods now displayed in a 4-column grid instead of a horizontal list, allowing quick access to more options.
  - **Visual Balance**: Adjusted vertical spacing between payment history and method selection.

## [2.5.12] - 2026-01-31
### Fixes
- **Build System**: Resolved Gradle build errors (`compileFlutterBuildRelease`) for smooth deployment.
- **Sync Stability**: Fixed modifier synchronization issues to ensure toppings are correctly saved and synced.

## [2.5.11] - 2026-01-30
### Settings Integration
- **Admin Controls**:
  - Integrated global switches for Auto Backup, Animations, and Marquee text.
  - Connected Tax, Rounding, and Discount toggles to POS logic.
  - Fixed timer conflicts for smooth UI animations.

### Improvements
- **Topping Pricing Enhancements**:
  - Implemented **Custom Price Input** for toppings during POS selection.
  - Added a dedicated **Price Dialog** with Numpad and Quick Price Buttons (1k, 2k, 5k, 10k).
  - Topping prices now default to 0 but can be easily overridden.
  - Improved UI feedback showing the selected price (e.g., "+Rp 2.000") or "GRATIS".

## [2.5.9] - 2026-01-31
### Synchronization System Overhaul
- **Unified Sync Architecture**:
  - Centralized synchronization logic using `SyncHelper`.
  - Consistent UI/UX for sync processes in both **Admin Dashboard** and **POS Menu**.
  - Standardized error handling, zero-data warnings, and success messages.
- **Dynamic Schema Adaptation**:
  - Implemented smart column detection to prevent crashes on legacy databases (handling missing or extra columns like `price_dinein`, `price_delivery`).
  - Automated `NOT NULL` constraint handling for legacy fields.
- **Enhanced POS Sync**:
  - **Direct Sync**: Synchronization (Products, Price Groups, etc.) can now be performed directly from the POS screen.
  - **Auto-Refresh**: POS data (prices, products) automatically reloads after a successful sync without restarting the app.
- **Robustness**:
  - Improved `Price Group` parsing to handle variable API response formats (List vs Map).
  - Added specific error logging for easier debugging of sync failures.

### Features
- **Split Payment System**:
  - **Multi-Method Support**: Single transactions can now be paid using multiple payment methods (e.g., partial Cash + partial Card).
  - **Dynamic Payment Dialog**: Redesigned payment interface to support "Add Payment" with remaining balance calculation.
  - **Receipt Enhancements**: 
    - Printed receipts now list all payment methods used and their respective amounts.
    - Change due is calculated correctly based on total paid across all methods.
  - **Backend Sync**: 
    - Split payments are synchronized to the ERP server as separate payment lines linked to the same transaction.
    - Fallback compatibility for legacy single-payment transactions.
- **Reporting**:
  - Updated "Laporan Shift" and "Z-Report" to reflect split payments correctly (summed by method type).

## [2.5.1] - 2026-01-29
### Customer Display System (CDS)
- **Feature**: Integrated Second Screen / Customer Display Support (HDMI/USB).
- **Functionality**:
  - Automatically displays Shopping Cart items and Real-time Total to customer.
  - Left-screen area reserved for Promotional Images carousel.
- **Customization**:
  - Added **"Layar Pelanggan"** menu in Admin Dashboard -> Settings.
  - **Dynamic Content**:
    - Configurable "Welcome Text" / Title.
    - Support for up to 3 Promotional Images (Carousel) via URL.
  - **On/Off Toggle**: Easily enable/disable the secondary display feature.
- **Backend Integration**:
  - Added `CustomerDisplaySetting` model and local caching.
  - Prepared synchronization with ERP Server for centralized management.

## [2.5.2] - 2026-01-29
### Reliability
- **Background Synchronization**:
  - Implementation of **Workmanager** for reliable background uploads.
  - Transactions now auto-sync every 15 minutes even if the app is minimized (Android).
  - Reduced risk of data loss due to forgotten manual uploads.

## [2.5.0] - 2026-01-29
### Major Update
- **Secondary Display Foundation**:
  - Switched to `flutter_presentation_display` for reliable multi-screen handling.
  - Added `CustomerDisplayScreen` UI.
  - Updated Android SDK `compileSdkVersion` to 36.
 
## [2.0.4] - 2026-01-27
### Printing & Branding Improvements
- **Robust Printing System**:
  - Implemented **Manual Raster Bit Image Mapping** for 100% compatibility with various Bluetooth thermal printers (Fixes ASCII characters issue).
  - Added **Auto-Trim & Aggressive Cropping** logic to remove white margins around business logos.
  - Automatic logo scaling to exactly **1/3 of paper width** (Optimized for 58mm and 80mm).
  - Eliminated redundant vertical spacing for a compact, tighter receipt layout.
- **Customizable Branding**:
  - Added **"Cetak Logo pada Struk"** toggle in Invoice Settings.
  - **Dynamic Title Logic**: Business header (Name, Address, Mobile) is now automatically hidden if Logo is enabled to prevent duplicate branding.
  - Integrated **Logo Debug Dialog** for real-time URI diagnostic and blind-search tracking.
- **Logo Synchronization**:
  - Enhanced `ApiService` with deep-search candidates for VPS storage patterns.
  - Explicitly exposed `logo_url` and `logo` data in ERP Connector resources.

## [2.0.3] - 2026-01-27
### Fixes & Improvements
- **UI Consistency**:
  - Unified Report Screen design with Admin Dashboard (Clean Light Theme).
  - Fixed invisible text issues in Report Summary.
  - Refactored "Manual Discount", "Customer Manager", and "Payment Dialog" to use consistent Clean Light Theme.
  - Renamed "System Info" dialog to "Discount Info" and updated to Clean Light Theme.
  - Enhanced Staff Login Screen:
    - Formatted transaction totals with currency.
    - Added "BELUM CLOSING" warning indicator.
    - Repositioned Logout button and improved its visibility (High Contrast).
    - Redesigned Setup Screen with clickable QR Codes (w/ confirmation dialog) and Professional Connection Button.
    - Optimized Branding Panel layout for Tablets (Centered, 50% width, optimized for 7" screens).
    - Added "Terms of Service" Agreement Dialog before Server Connection setup.
    - Improved Logo Sync Logic: Now supports custom upload paths and forces UI refresh.
    - Added "Printer Settings" menu in Admin Dashboard for easier configuration.
- **Bug Fixes**:
  - Resolved "Sale Type" selection dialog freezing issue.
  - Stabilized POS screen layout.

## [2.0.2] - 2026-01-26
### Features
- **Database Maintenance**:
  - Added **Backup Database** feature in Cashier Main Menu and Admin Dashboard.
  - Added **Restore Database** feature in Admin Dashboard with file picker.
- **POS & Discount Redesign**:
  - Full UI overhaul of Manual Discount dialog (Grey/Modern Aesthetic).
  - Redesigned **Local Discount Management** with compact, seamless layout.
- **Improvements**:
  - Fixed manual discount calculation bug (per-item logic).
  - Added automatic thousands separator for nominal discount input.
  - Improved UI contrast and font sizing across management dialogs.

## [2.0.1] - 2026-01-25
### Features & Improvements
- **Customer Management Overhaul**:
  - Improved UI with deep gray background for better contrast and accessibility.
  - Compact and seamless layout optimized for tablet displays.
  - Instant search feature for quick customer lookup (Server & Local).
- **UI Enhancements**:
  - Modernized `GlassDialog` design with dark theme support.
  - Implemented "Pelanggan Umum" as default entry for fast checkout.

## [2.0.0] - 2026-01-24
### Major Updates
- **Multi-Price System**: Added support for 4 distinct price tiers per product:
  - Dine In (Standard)
  - Take Away
  - Online (Gojek/Grab/Shopee)
  - Member (Special Pricing)
- **Sale Type Management**: 
  - New "Member" sale type option in POS.
  - Automatic price adjustment based on selected sale type.
- **Admin Dashboard Overhaul**:
  - Moved "Product Price Manager" to Admin Dashboard (secured access).
  - UI improvements for Admin Dashboard.

### Features
- **Product Price Manager (Admin)**:
  - New Split-Layout Design: distinct list view and numpad control.
  - Custom Numpad: Optimized for touchscreens with larger buttons.
  - Quick Price Editing: Edit Dine In, Take Away, Online, and Member prices individually.
  - Nominal Discount: Added support for fixed-amount discounts (replacing/supplementing percentage logic).
- **Reports**:
  - New **"Sale Type Summary"** report: Breakdown of sales by category (Dine In vs Take Away vs Online vs Member).
  - Printer support for Sale Type Summary.

### Database
- **Schema Update v7**:
  - Added `price_member` column to `products` table.
  - Added `discount_nominal` column to `products` table.

### Fixes & Improvements
- Optimized Numpad layout for better accessibility.
- Fixed product filtering and search logic in Manager.
- Improved overall UI consistency in Admin panels.
