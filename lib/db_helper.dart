/**
 * File: db_helper.dart
 * Deskripsi: Manajemen database SQLite lokal (Sqflite) untuk aplikasi DonaPOS.
 * Update Terakhir: 2026-02-03 15:55 (WIB)
 */

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:donapos_mobile/models.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const int schemaVersion = 48;
  static const String dbFileName = 'donapos_v11.db';
  final List<String> migrationLogs = [];

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(dbFileName);
    return _database!;
  }

  // Inisialisasi database SQLite dengan versi skema tertentu
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    migrationLogs.clear();
    migrationLogs.add("Opening database at version $schemaVersion...");

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    return await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createDB,
      onUpgrade: (db, oldV, newV) async {
        migrationLogs.add("Migration started: $oldV -> $newV");
        try {
          await _onUpgrade(db, oldV, newV);
          migrationLogs.add("Migration successful!");
        } catch (e) {
          migrationLogs.add("Migration FAILED: $e");
          rethrow;
        }
      }
    );
  }

  Future<bool> isMigrationNeeded() async {
     final dbPath = await getDatabasesPath();
     final path = join(dbPath, dbFileName);
     if (!await File(path).exists()) return false;

     final db = await openDatabase(path);
     final currentVersion = await db.getVersion();
     await db.close();

     return currentVersion > 0 && currentVersion < schemaVersion;
  }

  Future<int> getLocalVersion() async {
     final dbPath = await getDatabasesPath();
     final path = join(dbPath, dbFileName);
     if (!await File(path).exists()) return 0;

     final db = await openDatabase(path);
     final currentVersion = await db.getVersion();
     await db.close();
     return currentVersion;
  }

  Future<void> resetDatabase() async {
     final dbPath = await getDatabasesPath();
     final path = join(dbPath, dbFileName);

     try {
       // 1. Close existing connection
       await closeDB();

       if (await File(path).exists()) {
          try {
             // 2. Try to physical delete
             await deleteDatabase(path);
             migrationLogs.add("Database deleted & reset successfully.");
          } catch (e) {
             print("DB: Failed to delete database file (Locked?): $e");
             print("DB: Falling back to clearing all tables...");
             // 3. Fallback: Re-open and DELETE FROM tables
             await clearAllData();
          }
       }
     } catch (e) {
       print("DB: CRITICAL ERROR during reset: $e");
       // Last resort
       try { await clearAllData(); } catch (_) {}
     }
  }

  Future<void> closeDB() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // Menangani pembaruan skema database (migrasi kolom/tabel baru)
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      migrationLogs.add("Upgrading to v2: Adding payment_method...");
      await db.execute('ALTER TABLE transactions ADD COLUMN payment_method TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN cashier_name TEXT');
    }
    if (oldVersion < 3) {
      migrationLogs.add("Upgrading to v3: Adding is_closed to transactions...");
      await db.execute('ALTER TABLE transactions ADD COLUMN is_closed INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      migrationLogs.add("Upgrading to v4: Adding is_hold to transactions...");
      await db.execute('ALTER TABLE transactions ADD COLUMN is_hold INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      migrationLogs.add("Upgrading to v5: Creating attendances table...");
      await db.execute("""
        CREATE TABLE attendances (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          username TEXT NOT NULL,
          clock_in TEXT NOT NULL,
          clock_out TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      """);
    }
    if (oldVersion < 6) {
      // Add price_member to products
      try {
        await db.execute('ALTER TABLE products ADD COLUMN price_member REAL DEFAULT 0');
      } catch (e) {
        print("Column price_member might already exist: $e");
      }
    }
    if (oldVersion < 7) {
      migrationLogs.add("Upgrading to v7: Adding discount_nominal to products...");
      try {
        await db.execute('ALTER TABLE products ADD COLUMN discount_nominal REAL DEFAULT 0');
      } catch (e) {
        migrationLogs.add("Warning v7: $e");
      }
    }
    if (oldVersion < 8) {
      migrationLogs.add("Upgrading to v8: Creating local_discounts table...");
      await db.execute("""
        CREATE TABLE local_discounts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          starts_at TEXT NOT NULL,
          ends_at TEXT NOT NULL,
          category_id INTEGER,
          category_name TEXT,
          discount_type TEXT NOT NULL,
          discount_value REAL NOT NULL,
          is_active INTEGER DEFAULT 0
        )
      """);
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN sku TEXT');
      } catch (e) {
        print("Column sku might already exist: $e");
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN shift_id INTEGER DEFAULT 1');
      } catch (e) {
        print("Column shift_id might already exist: $e");
      }
    }
    if (oldVersion < 11) {
      await db.execute("""
        CREATE TABLE contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          contact_id TEXT,
          name TEXT NOT NULL,
          mobile TEXT,
          email TEXT,
          address TEXT,
          city TEXT,
          state TEXT,
          zip_code TEXT,
          is_synced INTEGER DEFAULT 1
        )
      """);
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN customer_id INTEGER');
        await db.execute('ALTER TABLE transactions ADD COLUMN customer_name TEXT');
      } catch (e) {
        print("Customer columns might already exist: $e");
      }
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN discount_nominal REAL DEFAULT 0');
      } catch (e) {}
      await db.execute("""
        CREATE TABLE IF NOT EXISTS contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER,
          contact_id TEXT,
          name TEXT NOT NULL,
          mobile TEXT,
          email TEXT,
          address TEXT,
          city TEXT,
          state TEXT,
          zip_code TEXT,
          is_synced INTEGER DEFAULT 1
        )
      """);
    }
    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN manual_discount REAL DEFAULT 0');
      } catch (e) {
        print("manual_discount column might already exist: $e");
      }
    }
    if (oldVersion < 15) {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS payment_methods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          label TEXT,
          is_active INTEGER DEFAULT 1
        )
      """);
      // Insert default methods
      await db.insert('payment_methods', {'name': 'cash', 'label': 'Tunai'});
      await db.insert('payment_methods', {'name': 'card', 'label': 'Kartu'});
      await db.insert('payment_methods', {'name': 'transfer', 'label': 'Transfer'});
      await db.insert('payment_methods', {'name': 'qris', 'label': 'QRIS'});
      await db.insert('payment_methods', {'name': 'other', 'label': 'Lainnya'});
    }
    if (oldVersion < 16) {
      await db.execute("""
        CREATE TABLE modifier_sets (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      """);
      await db.execute("""
        CREATE TABLE modifier_options (
          id INTEGER PRIMARY KEY,
          modifier_set_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL
        )
      """);
      await db.execute("""
        CREATE TABLE product_modifier_sets (
          product_id INTEGER NOT NULL,
          modifier_set_id INTEGER NOT NULL,
          PRIMARY KEY (product_id, modifier_set_id)
        )
      """);
    }
    if (oldVersion < 17) {
       // Ensure tables exist for users who might have missed v16 migration properly
       await db.execute("""
        CREATE TABLE IF NOT EXISTS modifier_sets (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      """);
      await db.execute("""
        CREATE TABLE IF NOT EXISTS modifier_options (
          id INTEGER PRIMARY KEY,
          modifier_set_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL
        )
      """);
      await db.execute("""
        CREATE TABLE IF NOT EXISTS product_modifier_sets (
          product_id INTEGER NOT NULL,
          modifier_set_id INTEGER NOT NULL,
          PRIMARY KEY (product_id, modifier_set_id)
        )
      """);
    }

    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN amount_paid REAL DEFAULT 0');
        await db.execute('ALTER TABLE transactions ADD COLUMN change_amount REAL DEFAULT 0');
      } catch (e) {}
    }

    if (oldVersion < 20) {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS expense_categories (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL
        )
      """);
      await db.execute("""
        CREATE TABLE IF NOT EXISTS local_expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER,
          final_total REAL NOT NULL,
          transaction_date TEXT NOT NULL,
          additional_notes TEXT,
          is_synced INTEGER DEFAULT 0
        )
      """);
    }

    if (oldVersion < 21) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN local_image_path TEXT');
      } catch (e) {
        print("Column local_image_path might already exist: $e");
      }
    }
    if (oldVersion < 22) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN res_service_staff_id INTEGER');
      } catch (e) {
         print("Column res_service_staff_id might already exist: $e");
      }
    }
    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN is_waiter INTEGER DEFAULT 0');
      } catch (e) {
         print("Column is_waiter might already exist: $e");
      }
    }
    if (oldVersion < 25) {
      // FORCE ADD MISSING COLUMNS JUST IN CASE
      try { await db.execute('ALTER TABLE transactions ADD COLUMN amount_paid REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE transactions ADD COLUMN change_amount REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE transactions ADD COLUMN pax INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE transactions ADD COLUMN res_service_staff_id INTEGER'); } catch (_) {}
    }
    if (oldVersion < 27) {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS transaction_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_id INTEGER NOT NULL,
          method TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          created_at TEXT
        )
      """);
    }
    if (oldVersion < 28) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN price REAL DEFAULT 0');
        await db.execute('UPDATE products SET price = price_dinein');
      } catch (e) {
        print("Migration v28 Error: $e");
      }
    }
    if (oldVersion < 32) {
      try {
        // Ensure transactions columns
        await db.execute('ALTER TABLE transactions ADD COLUMN cashier_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN is_refunded INTEGER DEFAULT 0');
      } catch (_) {}

      try {
        // Ensure transaction_items columns
        await db.execute('ALTER TABLE transaction_items ADD COLUMN discount REAL DEFAULT 0');
      } catch (_) {}

      try {
        // Ensure contacts columns
        await db.execute('ALTER TABLE contacts ADD COLUMN is_default INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE contacts ADD COLUMN customer_group_id INTEGER');
      } catch (_) {}

      try {
        // Ensure customer_groups table exists
        await db.execute("""
          CREATE TABLE IF NOT EXISTS customer_groups (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            amount REAL,
            price_calculation_type TEXT,
            selling_price_group_id INTEGER
          )
        """);
      } catch (_) {}
    }
    if (oldVersion <= 34) {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS transaction_item_modifiers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          transaction_item_id INTEGER NOT NULL,
          modifier_option_id INTEGER NOT NULL,
          modifier_name TEXT NOT NULL,
          price REAL NOT NULL
        )
      """);
    }
    if (oldVersion < 34) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN invoice_no TEXT');
      } catch (_) {}
    }
    if (oldVersion < 36) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN hold_note TEXT');
      } catch (_) {}
    }
    if (oldVersion < 37) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN is_local INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 38) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN server_variation_id INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 39) {
      await db.execute("""
        CREATE TABLE IF NOT EXISTS local_products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          unit_name TEXT,
          sku TEXT,
          purchase_price REAL DEFAULT 0,
          selling_price REAL DEFAULT 0,
          enable_stock INTEGER DEFAULT 1,
          alert_quantity REAL DEFAULT 0,
          tax_type TEXT DEFAULT 'inclusive',
          product_type TEXT DEFAULT 'single',
          image_path TEXT,
          category_name TEXT,
          brand_name TEXT,
          is_transferred_local INTEGER DEFAULT 0,
          is_transferred_server INTEGER DEFAULT 0,
          server_id INTEGER,
          created_at TEXT
        )
      """);
    }

    if (oldVersion < 40) {
      try { await db.execute('ALTER TABLE products ADD COLUMN price_dinein REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN price_online REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN price_takeaway REAL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN price_member REAL DEFAULT 0'); } catch (_) {}
    }

    if (oldVersion < 41) {
      migrationLogs.add("Upgrading to v41: Adding is_featured to products...");
      try { await db.execute('ALTER TABLE products ADD COLUMN is_featured INTEGER DEFAULT 0'); } catch (e) { migrationLogs.add("Warning v41: $e"); }
    }

    if (oldVersion < 42) {
      migrationLogs.add("Upgrading to v42: Adding needs_label to products...");
      try { await db.execute('ALTER TABLE products ADD COLUMN needs_label INTEGER DEFAULT 0'); } catch (e) { migrationLogs.add("Warning v42: $e"); }
    }

    if (oldVersion < 43) {
      migrationLogs.add("Upgrading to v43: Adding synced to attendances...");
      try { await db.execute('ALTER TABLE attendances ADD COLUMN synced INTEGER DEFAULT 0'); } catch (e) { migrationLogs.add("Warning v43: $e"); }
    }
    if (oldVersion < 44) {
      migrationLogs.add("Upgrading to v44: Ensuring synced column in attendances...");
      try {
        await db.execute('ALTER TABLE attendances ADD COLUMN synced INTEGER DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 45) {
      migrationLogs.add("Upgrading to v45: Force resetting unsynced status...");
      try {
          await db.execute('UPDATE attendances SET synced = 0 WHERE synced IS NULL');
      } catch (e) {
          migrationLogs.add("Warning v45: $e");
      }
    }

    if (oldVersion < 46) {
      migrationLogs.add("Upgrading to v46: Adding location & IP to attendances...");
      try { await db.execute('ALTER TABLE attendances ADD COLUMN ip_address TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN latitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN longitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN address TEXT'); } catch (_) {}

      try { await db.execute('ALTER TABLE attendances ADD COLUMN clock_out_latitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN clock_out_longitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN clock_out_address TEXT'); } catch (_) {}
    }

    if (oldVersion < 47) {
      migrationLogs.add("Upgrading to v47: Adding Database Indexes...");
      try {
        await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
        await db.execute('CREATE INDEX idx_products_brand ON products(brand_id)');
        await db.execute('CREATE INDEX idx_transactions_date ON transactions(created_at)');
        await db.execute('CREATE INDEX idx_transactions_synced ON transactions(synced)');
        await db.execute('CREATE INDEX idx_transaction_items_id ON transaction_items(transaction_id)');
      } catch (e) {
        migrationLogs.add("Warning v47: $e");
      }
    }

    if (oldVersion < 48) {
      migrationLogs.add("Upgrading to v48: Patching missing attendance columns for fresh v47 installs...");
      try { await db.execute('ALTER TABLE attendances ADD COLUMN ip_address TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN latitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN longitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN address TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN clock_out_latitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN clock_out_longitude TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE attendances ADD COLUMN clock_out_address TEXT'); } catch (_) {}
    }
  }


  // ... (previous createDB logic)
  // Ensure table exists in creation too or rely on migrations if we are lazy, but better add to createDB if possible,
  // but for now I'll stick to onUpgrade migration for safety.

  // --- Transactions ---
  // --- Unified Transaction Persistence (Control Template) ---
  // Menyimpan transaksi lengkap (Header, Baris Item, Modifikasi, Pembayaran) dalam satu transaksi SQL
  Future<int> persistTransaction(PosTransaction tx) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
       // Safety: Ensure table exists
       await txn.execute("""
         CREATE TABLE IF NOT EXISTS transaction_item_modifiers (
           id INTEGER PRIMARY KEY AUTOINCREMENT,
           transaction_item_id INTEGER NOT NULL,
           modifier_option_id INTEGER NOT NULL,
           modifier_name TEXT NOT NULL,
           price REAL NOT NULL
         )
       """);

       int txId;

       if (tx.id != null) {
           // Update Existing
           txId = tx.id!;
           await txn.update('transactions', tx.toHeaderMap(), where: 'id = ?', whereArgs: [txId]);

           // Clean up sub-tables
           final oldItems = await txn.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId], columns: ['id']);
           for (var row in oldItems) {
               await txn.delete('transaction_item_modifiers', where: 'transaction_item_id = ?', whereArgs: [row['id']]);
           }
           await txn.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
           await txn.delete('transaction_payments', where: 'transaction_id = ?', whereArgs: [txId]);
       } else {
           // Insert New
           txId = await txn.insert('transactions', tx.toHeaderMap());
       }

       // Insert Items & Modifiers
       for (var item in tx.items) {
          int itemId = await txn.insert('transaction_items', item.toMap(txId));
          for (var mod in item.modifiers) {
              await txn.insert('transaction_item_modifiers', mod.toMap(itemId));
          }
       }

       // Insert Payments
       for (var pay in tx.payments) {
           await txn.insert('transaction_payments', pay.toMap(txId));
       }

       return txId;
    });
  }

  // Deprecated: Old methods kept calling new unified one or kept for simple legacy flows
  Future<int> saveFullTransaction(
      Map<String, dynamic> txData,
      List<Map<String, dynamic>> items,
      {List<Map<String, dynamic>>? payments}
  ) async {
      // For compatibility during transition, we can still use this but it's better to move to PosTransaction model
      final db = await instance.database;
      return await db.transaction((txn) async {
          int txId = await txn.insert('transactions', txData);
          for (var item in items) {
              final itemInsert = {
                  'transaction_id': txId,
                  'product_id': item['product_id'],
                  'qty': item['qty'],
                  'price': item['price'],
                  'note': item['note'],
                  'discount': item['discount'] ?? 0,
              };
              int itemId = await txn.insert('transaction_items', itemInsert);
              if (item['modifiers'] != null) {
                  for (var mod in item['modifiers']) {
                      await txn.insert('transaction_item_modifiers', {
                          'transaction_item_id': itemId,
                          'modifier_option_id': mod['modifier_option_id'],
                          'modifier_name': mod['modifier_name'],
                          'price': mod['price'],
                      });
                  }
              }
          }
          if (payments != null) {
              for (var p in payments) {
                  await txn.insert('transaction_payments', {
                      'transaction_id': txId,
                      'method': p['method'],
                      'amount': p['amount'],
                      'note': p['note'] ?? '',
                      'created_at': DateTime.now().toIso8601String(),
                  });
              }
          }
          return txId;
      });
  }

  Future<void> updateFullTransaction(int txId, Map<String, dynamic> txData, List<Map<String, dynamic>> items, {List<Map<String, dynamic>>? payments}) async {
      // Redirect to a similar logic as persistTransaction but with Map if needed,
      // but ideally we should update the controller to use persistTransaction(tx).
      // Keeping it here with fixed logic to avoid breakage.
      final db = await instance.database;
      await db.transaction((txn) async {
         await txn.update('transactions', txData, where: 'id = ?', whereArgs: [txId]);
         final oldItems = await txn.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId], columns: ['id']);
         for (var oldItem in oldItems) {
             await txn.delete('transaction_item_modifiers', where: 'transaction_item_id = ?', whereArgs: [oldItem['id']]);
         }
         await txn.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
         await txn.delete('transaction_payments', where: 'transaction_id = ?', whereArgs: [txId]);

         for (var item in items) {
            int itemId = await txn.insert('transaction_items', {
                'transaction_id': txId,
                'product_id': item['product_id'],
                'qty': item['qty'],
                'price': item['price'],
                'note': item['note'],
                'discount': item['discount'] ?? 0,
            });
            if (item['modifiers'] != null) {
                for (var mod in item['modifiers']) {
                    await txn.insert('transaction_item_modifiers', {
                        'transaction_item_id': itemId,
                        'modifier_option_id': mod['modifier_option_id'],
                        'modifier_name': mod['modifier_name'],
                        'price': mod['price'],
                    });
                }
            }
         }
         if (payments != null) {
             for (var p in payments) {
                 await txn.insert('transaction_payments', {
                     'transaction_id': txId,
                     'method': p['method'],
                     'amount': p['amount'],
                     'note': p['note'] ?? '',
                     'created_at': DateTime.now().toIso8601String(),
                 });
             }
         }
      });
  }

  Future<int> getLastTransactionId() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT MAX(id) FROM transactions')) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getTransactionItemModifiers(int itemId) async {
      final db = await instance.database;
      return await db.rawQuery("""
          SELECT tim.*, mo.modifier_set_id as product_id
          FROM transaction_item_modifiers tim
          LEFT JOIN modifier_options mo ON tim.modifier_option_id = mo.id
          WHERE tim.transaction_item_id = ?
      """, [itemId]);
  }

  Future<List<Map<String, dynamic>>> getTransactionItems(int txId) async {
      final db = await instance.database;
      return await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [txId]);
  }

  // --- Transactions Helpers to save (Old methods kept for compatibility or removed if unused, but saveFullTransaction replaces them) ---
  // ...

  // Membuat tabel-tabel utama saat database pertama kali dibuat
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const textNullable = 'TEXT';

    await db.execute("""
    CREATE TABLE products (
      id INTEGER PRIMARY KEY,
      parent_id INTEGER,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      discount_nominal REAL DEFAULT 0,
      category_id INTEGER,
      brand_id INTEGER,
      image_url TEXT,
      sku TEXT,
      local_image_path TEXT,
      is_local INTEGER DEFAULT 0,
      server_variation_id INTEGER,
      price_dinein REAL DEFAULT 0,
      price_online REAL DEFAULT 0,
      price_takeaway REAL DEFAULT 0,
      price_member REAL DEFAULT 0,
      is_featured INTEGER DEFAULT 0,
      needs_label INTEGER DEFAULT 0
    )
    """);
    migrationLogs.add("Table 'products' created with version $schemaVersion.");

    await db.execute("""
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL
    )
    """);

    await db.execute("""
    CREATE TABLE users (
      id INTEGER PRIMARY KEY,
      username TEXT NOT NULL,
      first_name TEXT NOT NULL,
      last_name TEXT,
      pin TEXT,
      profile_image TEXT,
      is_waiter INTEGER DEFAULT 0,
      is_admin INTEGER DEFAULT 0
    )
    """);

    // New Price Group Tables
    await db.execute("""
    CREATE TABLE price_groups (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL
    )
    """);

    await db.execute("""
    CREATE TABLE variation_group_prices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      variation_id INTEGER NOT NULL,
      price_group_id INTEGER NOT NULL,
      price REAL NOT NULL
    )
    """);

    // Tax Table
    await db.execute("""
    CREATE TABLE taxes (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL
    )
    """);

    // Discount Table
    await db.execute("""
    CREATE TABLE discounts (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      amount REAL NOT NULL,
      is_active INTEGER,
      starts_at TEXT,
      ends_at TEXT,
      priority INTEGER,
      brand_id INTEGER,
      category_id INTEGER,
      spg TEXT
    )
    """);

    await db.execute("""
    CREATE TABLE discount_variations (
      discount_id INTEGER NOT NULL,
      variation_id INTEGER NOT NULL,
      PRIMARY KEY (discount_id, variation_id)
    )
    """);

    // Restaurant Tables
    await db.execute("""
    CREATE TABLE res_tables (
      id INTEGER PRIMARY KEY,
      business_id INTEGER,
      location_id INTEGER,
      name TEXT NOT NULL,
      description TEXT
    )
    """);

    await db.execute("""
    CREATE TABLE transactions (
      id $idType,
      sale_type $textType,
      res_table_id INTEGER,
      subtotal $realType,
      discount $realType,
      tax $realType,
      total $realType,
      status $textType,
      created_at $textType,
      synced INTEGER NOT NULL DEFAULT 0,
      payment_method TEXT,
      cashier_id INTEGER,
      cashier_name TEXT,
      is_closed INTEGER DEFAULT 0,
      is_hold INTEGER DEFAULT 0,
      shift_id INTEGER DEFAULT 1,
      customer_id INTEGER,
      customer_name TEXT,
      manual_discount REAL DEFAULT 0,
      amount_paid REAL DEFAULT 0,
      change_amount REAL DEFAULT 0,
      res_service_staff_id INTEGER,
      pax INTEGER DEFAULT 0,
      is_refunded INTEGER DEFAULT 0,
      invoice_no TEXT,
      hold_note TEXT
    )
    """);

    await db.execute("""
    CREATE TABLE transaction_items (
      id $idType,
      transaction_id $integerType,
      product_id $integerType,
      qty $integerType,
      price $realType,
      note TEXT,
      discount REAL DEFAULT 0
    )
    """);

    await db.execute("""
    CREATE TABLE attendances (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      username TEXT NOT NULL,
      clock_in TEXT NOT NULL,
      clock_out TEXT,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      synced INTEGER DEFAULT 0,
      ip_address TEXT,
      latitude TEXT,
      longitude TEXT,
      address TEXT,
      clock_out_latitude TEXT,
      clock_out_longitude TEXT,
      clock_out_address TEXT
    )
    """);

    await db.execute("""
    CREATE TABLE local_discounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      starts_at TEXT NOT NULL,
      ends_at TEXT NOT NULL,
      category_id INTEGER,
      category_name TEXT,
      discount_type TEXT NOT NULL,
      discount_value REAL NOT NULL,
      is_active INTEGER DEFAULT 0
    )
    """);

    await db.execute("""
    CREATE TABLE contacts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_id INTEGER,
      contact_id TEXT,
      name TEXT NOT NULL,
      mobile TEXT,
      email TEXT,
      address TEXT,
      city TEXT,
      state TEXT,
      zip_code TEXT,
      customer_group_id INTEGER,
      is_default INTEGER DEFAULT 0,
      is_synced INTEGER DEFAULT 1
    )
    """);

    // local_products table removed


    await db.execute("""
    CREATE TABLE modifier_sets (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL
    )
    """);
    await db.execute("""
    CREATE TABLE modifier_options (
      id INTEGER PRIMARY KEY,
      modifier_set_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      price REAL NOT NULL
    )
    """);
    await db.execute("""
    CREATE TABLE product_modifier_sets (
      product_id INTEGER NOT NULL,
      modifier_set_id INTEGER NOT NULL,
      PRIMARY KEY (product_id, modifier_set_id)
    )
    """);

    await db.execute("""
    CREATE TABLE expense_categories (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL
    )
    """);

    await db.execute("""
    CREATE TABLE local_expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id INTEGER,
      final_total REAL NOT NULL,
      transaction_date TEXT NOT NULL,
      additional_notes TEXT,
      is_synced INTEGER DEFAULT 0
    )
    """);

    await db.execute("""
    CREATE TABLE transaction_payments (
      id $idType,
      transaction_id $integerType,
      method $textType,
      amount $realType,
      note TEXT,
      created_at TEXT
    )
    """);

    // MISSING TABLE FIX: payment_methods
    await db.execute("""
      CREATE TABLE IF NOT EXISTS payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        label TEXT,
        is_active INTEGER DEFAULT 1
      )
    """);
    await db.insert('payment_methods', {'name': 'cash', 'label': 'Tunai'});
    await db.insert('payment_methods', {'name': 'card', 'label': 'Kartu'});
    await db.insert('payment_methods', {'name': 'transfer', 'label': 'Transfer'});
    await db.insert('payment_methods', {'name': 'qris', 'label': 'QRIS'});
    await db.insert('payment_methods', {'name': 'other', 'label': 'Lainnya'});

    await db.execute("""
    CREATE TABLE transaction_item_modifiers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_item_id INTEGER NOT NULL,
      modifier_option_id INTEGER NOT NULL,
      modifier_name TEXT NOT NULL,
      price REAL NOT NULL
    )
    """);

    await db.execute("""CREATE TABLE customer_groups (id INTEGER PRIMARY KEY, name TEXT NOT NULL, amount REAL, price_calculation_type TEXT, selling_price_group_id INTEGER)""");

    // PERFORMANCE INDEXES
    await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
    await db.execute('CREATE INDEX idx_products_brand ON products(brand_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(created_at)');
    await db.execute('CREATE INDEX idx_transactions_synced ON transactions(synced)');
    await db.execute('CREATE INDEX idx_transaction_items_id ON transaction_items(transaction_id)');
  }

  // --- Customer Groups ---
  Future<void> insertCustomerGroup(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('customer_groups', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getCustomerGroupById(int id) async {
    final db = await instance.database;
    final res = await db.query('customer_groups', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllCustomerGroups() async {
    final db = await instance.database;
    return await db.query('customer_groups', orderBy: 'name ASC');
  }

  // --- Products ---
  Future<void> insertProduct(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('products', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getProductCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await instance.database;
    return await db.query('products');
  }

  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await instance.database;
    final res = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  // getLocalProducts and mergeLocalProduct removed

  Future<List<Map<String, dynamic>>> getProductsByCategory(int categoryId) async {
    final db = await instance.database;
    return await db.query('products', where: 'category_id = ?', whereArgs: [categoryId]);
  }

  Future<void> clearProducts() async {
    final db = await instance.database;
    await db.delete('products');
  }

  Future<void> clearProductImages() async {
      final db = await instance.database;
      await db.update('products', {'image_url': null, 'local_image_path': null});

      try {
          final directory = await getApplicationDocumentsDirectory();
          final imageDir = Directory('${directory.path}/product_images');
          if (await imageDir.exists()) {
              await imageDir.delete(recursive: true);
          }
      } catch (e) {
          print('Error deleting product images: $e');
      }
  }

  Future<int> updateProductImagePath(int productId, String path) async {
      final db = await instance.database;
      return await db.update(
          'products',
          {'local_image_path': path},
          where: 'id = ?',
          whereArgs: [productId]
      );
  }

  // --- Categories ---
  Future<void> insertCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('categories', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    final db = await instance.database;
    final res = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> clearCategories() async {
    final db = await instance.database;
    await db.delete('categories');
  }

  Future<int> getCategoryCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
  }

  // --- Users ---
  Future<void> insertUser(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await instance.database;
    return await db.query('users');
  }

  Future<Map<String, dynamic>?> getUserByPin(String pin) async {
      final db = await instance.database;
      final res = await db.query('users', where: 'pin = ?', whereArgs: [pin]);
      if (res.isNotEmpty) return res.first;
      return null;
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
      final db = await instance.database;
      final res = await db.query('users', where: 'username = ?', whereArgs: [username]);
      if (res.isNotEmpty) return res.first;
      return null;
  }
  Future<Map<String, dynamic>?> getUserById(int id) async {
      final db = await instance.database;
      final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) return res.first;
      return null;
  }


  Future<void> clearUsers() async {
    final db = await instance.database;
    await db.delete('users');
  }

  Future<void> updateUserWaiterStatus(int id, bool isWaiter) async {
    final db = await instance.database;
    await db.update('users', {'is_waiter': isWaiter ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<int>> getWaiterIds() async {
    final db = await instance.database;
    final res = await db.query('users', where: 'is_waiter = 1', columns: ['id']);
    return res.map((e) => e['id'] as int).toList();
  }

  Future<void> updateWaitersBatch(List<int> ids) async {
      final db = await instance.database;
      if (ids.isEmpty) return;
      // Reset all first if needed, but here we assume clearUsers happened before
      // Actually clearUsers deletes rows, so we inserting new ones.
      // After insert, we need to set is_waiter=1 for these IDs.
      String idList = ids.join(',');
      await db.rawUpdate('UPDATE users SET is_waiter = 1 WHERE id IN ($idList)');
  }

  Future<int> getUserCount() async {
    final db = await instance.database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
  }

  // --- Price Groups ---
  Future<void> clearPriceGroups() async {
      final db = await instance.database;
      await db.delete('price_groups');
  }

  Future<void> insertPriceGroup(Map<String, dynamic> row) async {
      final db = await instance.database;
      await db.insert('price_groups', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllPriceGroups() async {
      final db = await instance.database;
      return await db.query('price_groups');
  }

  // --- Variation Group Prices ---
  Future<void> clearVariationGroupPrices() async {
      final db = await instance.database;
      await db.delete('variation_group_prices');
  }

  Future<void> insertVariationGroupPrice(Map<String, dynamic> row) async {
      final db = await instance.database;
      await db.insert('variation_group_prices', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double?> getGroupPrice(int variationId, int groupId) async {
      final db = await instance.database;
      final res = await db.query(
          'variation_group_prices',
          columns: ['price'],
          where: 'variation_id = ? AND price_group_id = ?',
          whereArgs: [variationId, groupId]
      );
      if (res.isNotEmpty) return res.first['price'] as double;
      return null;
  }

  Future<Map<int, double>> getPricesForGroup(int groupId) async {
      final db = await instance.database;
      final res = await db.query(
          'variation_group_prices',
          columns: ['variation_id', 'price'],
          where: 'price_group_id = ?',
          whereArgs: [groupId]
      );

      final Map<int, double> prices = {};
      for (var row in res) {
          prices[row['variation_id'] as int] = row['price'] as double;
      }
      return prices;
  }

  // --- Taxes & Discounts ---
  Future<void> clearTaxes() async => await (await instance.database).delete('taxes');
  Future<void> insertTax(Map<String, dynamic> row) async => await (await instance.database).insert('taxes', row, conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Map<String, dynamic>>> getAllTaxes() async => await (await instance.database).query('taxes');

  Future<void> clearDiscounts() async {
      final db = await instance.database;
      await db.delete('discounts');
      await db.delete('discount_variations');
  }

  Future<void> insertDiscount(Map<String, dynamic> row) async {
      await (await instance.database).insert('discounts', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertDiscountVariation(int discountId, int variationId) async {
      await (await instance.database).insert('discount_variations', {
          'discount_id': discountId,
          'variation_id': variationId
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> getAllDiscounts() async {
      return await (await instance.database).query('discounts', where: 'is_active = 1', orderBy: 'priority DESC');
  }

  Future<List<int>> getDiscountVariations(int discountId) async {
      final db = await instance.database;
      final res = await db.query('discount_variations', where: 'discount_id = ?', whereArgs: [discountId]);
      return res.map<int>((e) => e['variation_id'] as int).toList();
  }

  // --- Local Discounts ---
  Future<void> insertLocalDiscount(Map<String, dynamic> row) async {
      final db = await instance.database;
      await db.insert('local_discounts', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllLocalDiscounts() async {
      final db = await instance.database;
      return await db.query('local_discounts', orderBy: 'id DESC');
  }
  Future<Map<String, dynamic>?> getContactById(int id) async {
      final db = await instance.database;
      var res = await db.query('contacts', where: 'server_id = ?', whereArgs: [id]);
      if (res.isNotEmpty) return res.first;
      res = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
      if (res.isNotEmpty) return res.first;
      return null;
  }


  Future<void> updateLocalDiscount(int id, Map<String, dynamic> row) async {
      final db = await instance.database;
      await db.update('local_discounts', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteLocalDiscount(int id) async {
      final db = await instance.database;
      await db.delete('local_discounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getActiveLocalDiscount() async {
      final db = await instance.database;
      final now = DateTime.now().toIso8601String();
      // Simple string comparison for dates works if ISO format
      final res = await db.query(
          'local_discounts',
          where: 'is_active = 1 AND starts_at <= ? AND ends_at >= ?',
          whereArgs: [now, now],
          limit: 1
      );
      return res.isNotEmpty ? res.first : null;
  }

  // --- Restaurant Tables ---
  Future<void> clearResTables() async {
      final db = await instance.database;
      await db.delete('res_tables');
  }

  Future<void> insertResTable(Map<String, dynamic> row) async {
      final db = await instance.database;
      await db.insert('res_tables', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllResTables() async {
      final db = await instance.database;
      return await db.query('res_tables', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getResTablesByLocation(int locationId) async {
      final db = await instance.database;
      return await db.query('res_tables', where: 'location_id = ?', whereArgs: [locationId], orderBy: 'name');
  }

  // --- Transactions ---

  /// Atomic transaction save to ensure data consistency


  Future<List<Map<String, dynamic>>> getTransactionPayments(int transactionId) async {
    final db = await instance.database;
    return await db.query('transaction_payments', where: 'transaction_id = ?', whereArgs: [transactionId]);
  }

  /// Atomic transaction update


  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  Future<void> insertTransactionItem(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('transaction_items', row);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedTransactions() async {
    final db = await instance.database;
    // Only upload finalized sales (not on hold)
    return await db.query('transactions', where: 'synced = ? AND is_hold = 0', whereArgs: [0]);
  }

  Future<int> getUnsyncedCount() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as total FROM transactions WHERE synced = 0 AND is_hold = 0');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> getTotalTransactionCount() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as total FROM transactions');
    return Sqflite.firstIntValue(res) ?? 0;
  }



  Future<List<Map<String, dynamic>>> getAllHeldTransactions() async {
    final db = await instance.database;
    return await db.query('transactions',
      where: 'is_hold = 1 AND is_closed = 0',
      orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getHeldTransactionByTable(int tableId) async {
    final db = await instance.database;
    final res = await db.query('transactions',
      where: 'res_table_id = ? AND is_hold = 1 AND is_closed = 0',
      whereArgs: [tableId],
      limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getTransactionById(int id) async {
    final db = await instance.database;
    final res = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.update('transactions', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTransactionItems(int transactionId) async {
    final db = await instance.database;
    await db.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [transactionId]);
  }

  Future<void> markTransactionAsFinal(int id) async {
    final db = await instance.database;
    await db.update('transactions', {'is_hold': 0, 'status': 'final'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTodayTransactions() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final start = '${today}T00:00:00';
    final end = '${today}T23:59:59';

    final db = await instance.database;
    // Join with payment_methods to get labels for "custom_pay_x"
    return await db.rawQuery("""
      SELECT t.*, COALESCE(pm.label, t.payment_method) as payment_method_label
      FROM transactions t
      LEFT JOIN payment_methods pm ON t.payment_method = pm.name
      WHERE t.created_at >= ? AND t.created_at <= ? AND t.is_hold = 0
      ORDER BY t.id DESC
    """, [start, end]);
  }

  Future<void> markTransactionSynced(int id) async {
    final db = await instance.database;
    await db.update('transactions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markTransactionUnsynced(int id) async {
    final db = await instance.database;
    await db.update('transactions', {'synced': 0}, where: 'id = ?', whereArgs: [id]);
  }



  Future<List<Map<String, dynamic>>> getTransactionsByDateRange(String startDate, String endDate) async {
    final db = await instance.database;
    // Optimize query to use index on created_at (if available) vs full table scan with SUBSTR
    // startDate and endDate are passed as yyyy-MM-dd
    // FIX: Using 'T' separator to match ISO8601 storage format in SQLite comparison
    final start = '${startDate}T00:00:00';
    final end = '${endDate}T23:59:59';

    return await db.query(
      'transactions',
      where: 'created_at >= ? AND created_at <= ? AND is_hold = 0',
      whereArgs: [start, end],
      orderBy: 'created_at DESC'
    );
  }

  Future<void> resetSales() async {
    final db = await instance.database;
    await db.delete('transactions');
    await db.delete('transaction_items');
    await db.delete('transaction_payments');
    await db.delete('transaction_item_modifiers');
    await db.delete('local_expenses');
    await db.delete('attendances');
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('products');
    await db.delete('categories');
    await db.delete('users');
    await db.delete('price_groups');
    await db.delete('variation_group_prices');
    await db.delete('taxes');
    await db.delete('discounts');
    await db.delete('discount_variations');
    await db.delete('res_tables');
    await db.delete('transactions');
    await db.delete('transaction_items');
    await db.delete('transaction_payments');
    await db.delete('transaction_item_modifiers');
    await db.delete('local_discounts');
    await db.delete('modifier_sets');
    await db.delete('modifier_options');
    await db.delete('product_modifier_sets');
    await db.delete('contacts');
    await db.delete('attendances');
    await db.delete('expense_categories');
    await db.delete('local_expenses');
    await db.delete('payment_methods');
    await db.delete('customer_groups');
  }

  Future<bool> hasDemoSnapshot() async {
    final dbPath = await getDatabasesPath();
    final demoPath = join(dbPath, 'donapos_demo.db');
    return await File(demoPath).exists();
  }

  Future<void> captureDemoSnapshot() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'donapos_v11.db');
    final demoPath = join(dbPath, 'donapos_demo.db');

    // Checkpoint to ensure all data is in the main file
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');

    final dbFile = File(path);
    if (await dbFile.exists()) {
      await dbFile.copy(demoPath);
    }
  }

  Future<void> restoreDemoSnapshot() async {
    final dbPath = await getDatabasesPath();
    final demoPath = join(dbPath, 'donapos_demo.db');
    final path = join(dbPath, 'donapos_v11.db');

    if (await File(demoPath).exists()) {
      await closeDB();

      // Delete existing WAL/SHM to be safe
      final walPath = '$path-wal';
      final shmPath = '$path-shm';
      if (await File(walPath).exists()) await File(walPath).delete();
      if (await File(shmPath).exists()) await File(shmPath).delete();

      final dbFile = File(path);
      if (await dbFile.exists()) await dbFile.delete();

      // Copy demo snapshot
      await File(demoPath).copy(path);
      return;
    }

    await clearAllData();
    final db = await instance.database;

    // Seed Users
    // Tashia = Admin
    await db.insert('users', {
      'id': 8,
      'username': 'tashia',
      'first_name': 'Admin',
      'last_name': 'Demo',
      'pin': '12345',
      'is_waiter': 0,
      'is_admin': 1
    });
    // Aurel = Kasir
    await db.insert('users', {
      'id': 6,
      'username': 'aurel',
      'first_name': 'Kasir',
      'last_name': 'Demo',
      'pin': '12345',
      'is_waiter': 0,
      'is_admin': 0
    });

    // Seed Categories
    await db.insert('categories', {'id': 1, 'name': 'MAKANAN'});
    await db.insert('categories', {'id': 2, 'name': 'MINUMAN'});
    await db.insert('categories', {'id': 3, 'name': 'SNACK'});

    // Seed Products
    // 1. Nasi Goreng (Featured, Standard)
    await db.insert('products', {
      'id': 1,
      'name': 'NASI GORENG SPESIAL',
      'price': 25000,
      'category_id': 1,
      'sku': 'FOOD001',
      'price_dinein': 25000,
      'price_online': 28000,
      'price_takeaway': 27000,
      'price_member': 25000 * 0.9,
      'is_featured': 1,
      'needs_label': 0,
      'image_url': 'https://images.unsplash.com/photo-1512058564366-18510be2db19?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80'
    });
    // 2. Es Teh (Beverage)
    await db.insert('products', {
      'id': 2,
      'name': 'ES TEH MANIS',
      'price': 5000,
      'category_id': 2,
      'sku': 'DRINK001',
      'price_dinein': 5000,
      'price_online': 6000,
      'price_takeaway': 5000,
      'price_member': 4500,
      'is_featured': 1,
      'needs_label': 0,
      'image_url': 'assets/images/demo_drink_1.png'
    });
    // 3. Kopi Susu (Needs Label)
    await db.insert('products', {
      'id': 3,
      'name': 'KOPI SUSU GULA AREN',
      'price': 18000,
      'category_id': 2,
      'sku': 'COFFEE01',
      'price_dinein': 18000,
      'price_online': 22000,
      'price_takeaway': 19000,
      'price_member': 17000,
      'is_featured': 1,
      'needs_label': 1,
      'image_url': 'https://images.unsplash.com/photo-1549520473-c603b573661b?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80'
    });

    // Seed Tables
    await db.insert('res_tables', {'id': 1, 'name': 'MEJA 01', 'location_id': 1});
    await db.insert('res_tables', {'id': 2, 'name': 'MEJA 02', 'location_id': 1});
    await db.insert('res_tables', {'id': 3, 'name': 'MEJA 03', 'location_id': 1});

    // Seed Taxes
    await db.insert('taxes', {'id': 1, 'name': 'PPN', 'amount': 10});

    // Seed Discounts
    await db.insert('discounts', {
      'id': 1,
      'name': 'PROMO OPENING',
      'type': 'percentage',
      'amount': 10,
      'is_active': 1,
      'priority': 1
    });

    // Seed Payment Methods
    final methods = [
       {'name': 'cash', 'label': 'TUNAI'},
       {'name': 'qris', 'label': 'QRIS'},
       {'name': 'transfer', 'label': 'TRANSFER BANK'},
       {'name': 'card', 'label': 'DEBIT/KREDIT'},
    ];
    for (var m in methods) {
        // Check duplicate if any (though we cleared data)
        await db.insert('payment_methods', m);
    }

    // Seed Default Contact
    await db.insert('contacts', {
      'id': 1,
      'name': 'Walk-In Customer (Demo)',
      'is_default': 1,
      'is_synced': 1
    });

    // Seed Member Contact
    await db.insert('contacts', {
      'id': 2,
      'name': 'Budi Member (Demo)',
      'mobile': '08123456789',
      'is_default': 0,
      'is_synced': 1
    });
  }
  Future<void> clearModifiers() async {
    final db = await instance.database;
    await db.delete('modifier_sets');
    await db.delete('modifier_options');
    await db.delete('product_modifier_sets');
  }

  Future<void> insertModifierSet(int id, String name) async {
    final db = await instance.database;
    await db.insert('modifier_sets', {
      'id': id,
      'name': name
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertModifierOption(int id, int setId, String name, double price) async {
    final db = await instance.database;
    await db.insert('modifier_options', {
      'id': id,
      'modifier_set_id': setId,
      'name': name,
      'price': price
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> linkProductToModifier(int productId, int setId) async {
    final db = await instance.database;
    await db.insert('product_modifier_sets', {
      'product_id': productId,
      'modifier_set_id': setId
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getProductModifiers(int productId) async {
    final db = await instance.database;

    // First, find if this product has a parent_id (is a variation)
    final pRes = await db.query('products', columns: ['parent_id'], where: 'id = ?', whereArgs: [productId]);
    int lookupId = productId;

    if (pRes.isNotEmpty && pRes.first['parent_id'] != null) {
        lookupId = pRes.first['parent_id'] as int;
    }

    // Now query modifier sets using either the product ID or its parent ID
    return await db.rawQuery("""
      SELECT ms.id as set_id, ms.name as set_name
      FROM modifier_sets ms
      JOIN product_modifier_sets pms ON ms.id = pms.modifier_set_id
      WHERE pms.product_id = ? OR pms.product_id = ?
    """, [productId, lookupId]);
  }

  Future<List<Map<String, dynamic>>> getModifierOptions(int setId) async {
    final db = await instance.database;
    return await db.query('modifier_options', where: 'modifier_set_id = ?', whereArgs: [setId]);
  }

  Future<Set<int>> getProductIdsWithModifiers() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT DISTINCT product_id FROM product_modifier_sets');
    return res.map((r) => r['product_id'] as int).toSet();
  }

  Future<int> debugCountModifierSets() async {
      final db = await instance.database;
      return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM modifier_sets')) ?? 0;
  }

  Future<int> debugCountLinks(int productId) async {
      final db = await instance.database;
      return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM product_modifier_sets WHERE product_id = ?', [productId])) ?? 0;
  }

  // --- Local Reports ---
  Future<Map<String, dynamic>> getLocalShiftReport(String? cashierName) async {
    final db = await instance.database;

    // FETCH ALL OPEN TRANSACTIONS (Active Session)
    // We do NOT filter by specific date, because a shift might span across midnight.
    // The "Shift" is defined as everything since the last closing (is_closed = 0).
    final List<Map<String, dynamic>> txs = await db.query(
      'transactions',
      where: "is_closed = 0 AND is_refunded = 0",
    );

    double omzetKotor = 0;
    double totalDiskon = 0;
    double pajak = 0;
    double totalBersih = 0;
    int totalItems = 0;

    Map<String, double> orderTypesMap = {};

    // Find Date Range
    String minDate = "";
    String maxDate = "";

    if (txs.isNotEmpty) {
       List<String> dates = txs.map((e) => e['created_at'] as String).toList();
       dates.sort();
       minDate = dates.first;
       maxDate = dates.last;
    } else {
       String now = DateTime.now().toIso8601String();
       minDate = now;
       maxDate = now;
    }

    // Format Dates for Display
    String periodStr = "-";
    if (txs.isNotEmpty) {
        String d1 = DateFormat('dd/MM HH:mm').format(DateTime.parse(minDate));
        String d2 = DateFormat('dd/MM HH:mm').format(DateTime.parse(maxDate));
        periodStr = "$d1 - $d2";
    }

    for (var tx in txs) {
      omzetKotor += (tx['subtotal'] as num).toDouble();
      totalDiskon += (tx['discount'] as num).toDouble();
      pajak += (tx['tax'] as num).toDouble();
      totalBersih += (tx['total'] as num).toDouble();

      // Order types
      String type = tx['sale_type']?.toString().toUpperCase() ?? 'DINEIN';
      orderTypesMap[type] = (orderTypesMap[type] ?? 0) + (tx['total'] as num).toDouble();

      // Get items count
      final itemsRes = await db.rawQuery('SELECT SUM(qty) as total_qty FROM transaction_items WHERE transaction_id = ?', [tx['id']]);
      if (itemsRes.isNotEmpty && itemsRes.first['total_qty'] != null) {
        totalItems += (itemsRes.first['total_qty'] as num).toInt();
      }
    }

    // NEW: Detailed Payment Breakdown Aggregated by Method Label
    final Map<String, double> paymentMethodsDetailed = {};
    final paymentsRes = await db.rawQuery("""
        SELECT
            CASE
                WHEN pm.label IS NOT NULL AND pm.label <> '' THEN pm.label
                WHEN tp.method = 'cash' THEN 'Tunai'
                WHEN tp.method = 'card' THEN 'Kartu'
                WHEN tp.method = 'transfer' THEN 'Bank'
                ELSE tp.method
            END as display_name,
            SUM(tp.amount) as total
        FROM transaction_payments tp
        JOIN transactions t ON tp.transaction_id = t.id
        LEFT JOIN payment_methods pm ON LOWER(tp.method) = LOWER(pm.name)
        WHERE t.is_closed = 0 AND t.is_refunded = 0
        GROUP BY display_name
    """);

    for (var row in paymentsRes) {
        String method = row['display_name'].toString();
        paymentMethodsDetailed[method] = (row['total'] as num).toDouble();
    }

    // Get expenses for active session
    // Logic: Expenses also need 'is_closed = 0' or 'is_synced = 0'?
    // Usually expenses are tied to Shift. If we don't have is_closed on expenses, we might use date.
    // However, user said "Revisi Total". Existing table local_expenses has no is_closed.
    // We should probably rely on date range of transactions? Or just fetch today's expenses?
    // Let's stick to "Today" for expenses as they are usually daily, OR allow expenses to be carried?
    // Safe bet: Expenses entered TODAY + Expenses in exact range?
    // Let's use the min/max date range of transactions to sum expenses.

    double totalExpenses = 0;
    if (minDate.isNotEmpty && maxDate.isNotEmpty) {
        final expRes = await db.rawQuery(
          'SELECT SUM(final_total) as total FROM local_expenses WHERE transaction_date >= ? AND transaction_date <= ?',
          [minDate, maxDate]
        );
         totalExpenses = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    final refundRes = await db.rawQuery(
      'SELECT SUM(total) as total FROM transactions WHERE is_closed = 0 AND is_refunded = 1'
    );
    double totalRefunded = (refundRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'kasir_name': cashierName ?? 'Local Cashier',
      'tanggal': periodStr, // Use Period String instead of single date
      'shift_id': 1,
      'jam_login': minDate.length > 11 ? minDate.substring(11, 19) : '00:00:00',
      'total_transactions': txs.length,
      'total_items': totalItems,
      'total_expenses': totalExpenses,
      'total_refunded': totalRefunded,
      'sales': {

        'omzet_kotor': omzetKotor,
        'total_diskon': totalDiskon,
        'pajak': pajak,
        'total_bersih': totalBersih,
      },
      'payments': paymentMethodsDetailed,
      'order_types': orderTypesMap.entries.map((e) => {'name': e.key, 'total_sales': e.value}).toList(),
    };
  }

  Future<Map<String, dynamic>> getLocalZReport() async {
    final db = await instance.database;

    // FETCH ALL OPEN TRANSACTIONS (For Closing)
    // Same logic as Shift Report: Everything that is not closed yet.
    final List<Map<String, dynamic>> txs = await db.query(
      'transactions',
      where: "is_closed = 0 AND is_refunded = 0",
    );

    double omzetKotor = 0;
    double totalDiskon = 0;
    double pajak = 0;
    double totalBersih = 0;
    int totalItems = 0;

    String minDate = "";
    String maxDate = "";

    if (txs.isNotEmpty) {
       List<String> dates = txs.map((e) => e['created_at'] as String).toList();
       dates.sort();
       minDate = dates.first;
       maxDate = dates.last;
    }

    String periodStr = DateFormat('dd MMM yyyy').format(DateTime.now());
    if (minDate.isNotEmpty) {
        String d1 = DateFormat('dd/MM HH:mm').format(DateTime.parse(minDate));
        String d2 = DateFormat('dd/MM HH:mm').format(DateTime.now()); // Until now
        periodStr = "$d1 - $d2";
    }

    for (var tx in txs) {
      omzetKotor += (tx['subtotal'] as num).toDouble();
      totalDiskon += (tx['discount'] as num).toDouble();
      pajak += (tx['tax'] as num).toDouble();
      totalBersih += (tx['total'] as num).toDouble();

      // Get items count
      final itemsRes = await db.rawQuery('SELECT SUM(qty) as total_qty FROM transaction_items WHERE transaction_id = ?', [tx['id']]);
      if (itemsRes.isNotEmpty && itemsRes.first['total_qty'] != null) {
        totalItems += (itemsRes.first['total_qty'] as num).toInt();
      }
    }

    // NEW: Detailed Z-Report Payment Breakdown by Label
    final Map<String, double> zPaymentMethodsDetailed = {};
    final zPaymentsRes = await db.rawQuery("""
        SELECT
            CASE
                WHEN pm.label IS NOT NULL AND pm.label <> '' THEN pm.label
                WHEN tp.method = 'cash' THEN 'Tunai'
                WHEN tp.method = 'card' THEN 'Kartu'
                WHEN tp.method = 'transfer' THEN 'Bank'
                ELSE tp.method
            END as display_name,
            SUM(tp.amount) as total
        FROM transaction_payments tp
        JOIN transactions t ON tp.transaction_id = t.id
        LEFT JOIN payment_methods pm ON LOWER(tp.method) = LOWER(pm.name)
        WHERE t.is_closed = 0 AND t.is_refunded = 0
        GROUP BY display_name
    """);

    for (var row in zPaymentsRes) {
        String method = row['display_name'].toString();
        zPaymentMethodsDetailed[method] = (row['total'] as num).toDouble();
    }

    // Get expenses
    double totalExpenses = 0;
    if (minDate.isNotEmpty) {
        final expRes = await db.rawQuery(
          'SELECT SUM(final_total) as total FROM local_expenses WHERE transaction_date >= ?',
          [minDate]
        );
         totalExpenses = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;
    }

    final refundRes = await db.rawQuery(
      'SELECT SUM(total) as total FROM transactions WHERE is_closed = 0 AND is_refunded = 1'
    );
    double totalRefunded = (refundRes.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'tanggal': periodStr,
      'total_kasir': 1,
      'total_transactions': txs.length,
      'total_items': totalItems,
      'total_expenses': totalExpenses,
      'total_refunded': totalRefunded,
      'status': 'OPEN SESSION',
      'total_sales': {
        'omzet_kotor': omzetKotor,
        'diskon': totalDiskon,
        'pajak': pajak,
        'total_bersih': totalBersih,
      },
      'payments': zPaymentMethodsDetailed,
    };
  }

  Future<List<Map<String, dynamic>>> getLocalProductSummary(String date) async {
    final db = await instance.database;

    // Query to get product summary for a specific date
    // We join transaction_items -> transactions (for date) -> products (for name)
    final List<Map<String, dynamic>> result = await db.rawQuery("""
      SELECT
        p.name as product_name,
        SUM(ti.qty) as total_qty,
        SUM(ti.qty * ti.price) as total_sales
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      JOIN products p ON ti.product_id = p.id
      WHERE SUBSTR(t.created_at, 1, 10) = ? AND t.is_closed = 0 AND t.is_refunded = 0
      GROUP BY ti.product_id
      ORDER BY total_qty DESC
    """, [date]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getLocalCategorySummaryRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> result = await db.rawQuery("""
      SELECT
        c.name as category_name,
        SUM(ti.qty) as total_qty,
        SUM(ti.qty * ti.price) as total_sales
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      JOIN products p ON ti.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE SUBSTR(t.created_at, 1, 10) BETWEEN ? AND ?
      AND t.is_hold = 0 AND t.is_refunded = 0
      GROUP BY p.category_id
      ORDER BY total_sales DESC
    """, [startStr, endStr]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getLocalSaleTypeSummary(String date) async {
    final db = await instance.database;

    final List<Map<String, dynamic>> result = await db.rawQuery("""
      SELECT
        sale_type,
        COUNT(*) as total_count,
        SUM(total) as total_sales
      FROM transactions
      WHERE SUBSTR(created_at, 1, 10) = ? AND is_closed = 0 AND is_refunded = 0
      GROUP BY sale_type
      ORDER BY total_sales DESC
    """, [date]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getSalesChartData(DateTime start, DateTime end) async {
    final db = await instance.database;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    // We want ALL valid sales (not just open ones), so we check status or just ignore is_closed
    // Typically for historical chart we include everything that is not voided/held
    return await db.rawQuery("""
      SELECT
        SUBSTR(created_at, 1, 10) as date,
        SUM(total) as total_sales
      FROM transactions
      WHERE SUBSTR(created_at, 1, 10) BETWEEN ? AND ?
      AND is_hold = 0 AND is_refunded = 0
      GROUP BY date
      ORDER BY date ASC
    """, [startStr, endStr]);
  }

  Future<void> refundTransaction(int txId) async {
    final db = await instance.database;
    await db.update('transactions', {'is_refunded': 1, 'synced': 0}, where: 'id = ?', whereArgs: [txId]);
  }

  Future<void> closeDayLocal() async {
      final db = await instance.database;
      await db.update('transactions', {'is_closed': 1}, where: 'is_closed = 0');
  }

  // --- Attendances ---
  Future<int> clockIn(int userId, String username, {String? ip, String? lat, String? long, String? address}) async {
    final db = await instance.database;
    return await db.insert('attendances', {
      'user_id': userId,
      'username': username,
      'clock_in': DateTime.now().toIso8601String(),
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
      'ip_address': ip,
      'latitude': lat,
      'longitude': long,
      'address': address
    });
  }

  Future<void> clockOut(int userId, {String? lat, String? long, String? address}) async {
    final db = await instance.database;
    await db.update('attendances', {
      'clock_out': DateTime.now().toIso8601String(),
      'status': 'finished',
      'synced': 0,
      'clock_out_latitude': lat,
      'clock_out_longitude': long,
      'clock_out_address': address
    }, where: 'user_id = ? AND status = ?', whereArgs: [userId, 'active']);
  }

  Future<Map<String, dynamic>?> getActiveAttendance(int userId) async {
    final db = await instance.database;
    final res = await db.query('attendances',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, 'active'],
      limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAttendanceLogs({String? startDate, String? endDate, int limit = 50}) async {
    final db = await instance.database;
    if (startDate != null && endDate != null) {
      return await db.query('attendances',
        where: 'SUBSTR(created_at, 1, 10) BETWEEN ? AND ?',
        whereArgs: [startDate, endDate],
        orderBy: 'id DESC',
        limit: limit);
    }
    return await db.query('attendances', orderBy: 'id DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAttendances() async {
    final db = await instance.database;
    return await db.query('attendances', where: 'synced = 0');
  }

  Future<void> markAttendanceSynced(int id) async {
    final db = await instance.database;
    await db.update('attendances', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProducts({
    int? categoryId,
    String? searchQuery,
    int offset = 0,
    int limit = 20,
    bool onlyFeatured = false
  }) async {
    final db = await instance.database;
    String whereClause = '1=1'; // Always true
    List<dynamic> whereArgs = [];

    if (categoryId != null) {
      whereClause += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    if (onlyFeatured) {
       whereClause += ' AND is_featured = 1';
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Basic fuzzy search
      whereClause += ' AND (name LIKE ? OR sku LIKE ?)';
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    // Always hide not-for-selling or inactive if we had that flag (assuming sync handles it by not inserting)

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'name ASC' // Alphabetical sort
    );

    return maps;
  }

  Future<void> setFeaturedProducts(List<String> productIds) async {
      final db = await instance.database;
      // 1. Reset all featured
      await db.update('products', {'is_featured': 0});

      // 2. Set new featured
      // Convert string IDs to list of ints for query
      // The API sends strings, but our local ID is integer.
      // Be careful: if our local ID IS the server variation ID (storageId method), then we can match directly.
      // Or we match by parent_id? No, featured_products usually refers to specific variations in ERP logic.
      // In our syncProducts, we store variation ID as the primary ID (storageId).

      if (productIds.isEmpty) return;

      Batch batch = db.batch();
      for (var idStr in productIds) {
          int? id = int.tryParse(idStr);
          if (id != null) {
              batch.update('products', {'is_featured': 1}, where: 'id = ?', whereArgs: [id]);
              // Also update by server_variation_id just in case
              batch.update('products', {'is_featured': 1}, where: 'server_variation_id = ?', whereArgs: [id]);
          }
      }
      await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>> getSystemStatus() async {
    final db = await instance.database;
    final productCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
    final categoryCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
    final tableCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM res_tables')) ?? 0;
    final discountCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM discounts')) ?? 0;

    // Check if day is closed (current active transactions)
    final activeTransactions = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM transactions WHERE is_closed = 0')) ?? 0;

    // Last transaction
    final List<Map<String, dynamic>> lastTx = await db.query(
      'transactions',
      orderBy: 'id DESC',
      limit: 1,
    );

    Map<String, dynamic>? lastTxInfo;
    if (lastTx.isNotEmpty) {
        lastTxInfo = Map<String, dynamic>.from(lastTx.first);
    }

    return {
      'products': productCount,
      'categories': categoryCount,
      'tables': tableCount,
      'discounts': discountCount,
      'is_day_active': activeTransactions > 0,
      'last_transaction': lastTxInfo,
    };
  }

  // --- Contacts / Pelanggan ---
  Future<int> insertContact(Map<String, dynamic> contact) async {
    final db = await instance.database;
    return await db.insert('contacts', contact, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearAllContacts() async {
    final db = await instance.database;
    await db.delete('contacts');
  }

  Future<void> clearContacts() async {
    final db = await instance.database;
    await db.delete('contacts', where: 'server_id IS NOT NULL');
  }

  Future<List<Map<String, dynamic>>> getAllContacts() async {
    final db = await instance.database;
    return await db.query('contacts', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedContacts() async {
    final db = await instance.database;
    return await db.query('contacts', where: 'is_synced = 0');
  }

  Future<void> markContactSynced(int localId, int serverId, String contactId) async {
    final db = await instance.database;
    await db.update('contacts', {
      'server_id': serverId,
      'contact_id': contactId,
      'is_synced': 1
    }, where: 'id = ?', whereArgs: [localId]);
  }

  Future<Map<String, dynamic>?> getContactByLocalId(int id) async {
    final db = await instance.database;
    final res = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<Map<String, dynamic>?> getDefaultContact() async {
    final db = await instance.database;
    final rs = await db.query('contacts', where: 'is_default = 1', limit: 1);
    if (rs.isNotEmpty) return rs.first;
    return null;
  }

  Future<void> setDefaultContact(int id) async {
    final db = await instance.database;
    await db.update('contacts', {'is_default': 0});
    await db.update('contacts', {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // --- Expenses ---
  Future<void> insertExpenseCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    await db.insert('expense_categories', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllExpenseCategories() async {
    final db = await instance.database;
    return await db.query('expense_categories', orderBy: 'name ASC');
  }

  Future<void> clearExpenseCategories() async {
    final db = await instance.database;
    await db.delete('expense_categories');
  }

  Future<int> insertLocalExpense(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('local_expenses', row);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await instance.database;
    return await db.query('local_expenses', where: 'is_synced = 0');
  }

  Future<void> markExpenseSynced(int id) async {
    final db = await instance.database;
    await db.update('local_expenses', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTodayTotalExpenses() async {
    final db = await instance.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final res = await db.rawQuery('SELECT SUM(final_total) as total FROM local_expenses WHERE SUBSTR(transaction_date, 1, 10) = ?', [today]);
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Map<String, dynamic>>> getExpenseReport(DateTime start, DateTime end) async {
    final db = await instance.database;
    final startStr = DateFormat('yyyy-MM-dd').format(start) + " 00:00:00";
    final endStr = DateFormat('yyyy-MM-dd').format(end) + " 23:59:59";

    return await db.rawQuery("""
        SELECT e.*, ec.name as category_name
        FROM local_expenses e
        LEFT JOIN expense_categories ec ON e.category_id = ec.id
        WHERE e.transaction_date >= ? AND e.transaction_date <= ?
        ORDER BY e.transaction_date DESC
    """, [startStr, endStr]);
  }

  Future<List<Map<String, dynamic>>> getTableReport(DateTime date) async {
      final db = await instance.database;
      final today = DateFormat('yyyy-MM-dd').format(date);
      final start = '${today}T00:00:00';
      final end = '${today}T23:59:59';

      final result = await db.rawQuery("""
          SELECT
              t.res_table_id,
              rt.name as table_name,
              COUNT(t.id) as total_transactions,
              SUM(t.pax) as total_pax,
              SUM(t.total) as total_revenue
          FROM transactions t
          LEFT JOIN res_tables rt ON t.res_table_id = rt.id
          WHERE t.created_at >= ? AND t.created_at <= ?
            AND t.is_hold = 0
            AND t.is_refunded = 0
            AND t.res_table_id IS NOT NULL
          GROUP BY t.res_table_id
          ORDER BY total_revenue DESC
      """, [start, end]);

      return result;
  }

  // --- Product Report ---
  Future<List<Map<String, dynamic>>> getProductReport(DateTime startDate, DateTime endDate) async {
      final db = await instance.database;
      final s = DateFormat('yyyy-MM-dd').format(startDate);
      final e = DateFormat('yyyy-MM-dd').format(endDate);
      final start = '${s}T00:00:00';
      final end = '${e}T23:59:59';

      final result = await db.rawQuery("""
          SELECT
              ti.product_id,
              p.name as product_name,
              SUM(ti.qty) as total_qty,
              SUM(ti.price * ti.qty) as total_revenue
          FROM transaction_items ti
          JOIN transactions t ON ti.transaction_id = t.id
          JOIN products p ON ti.product_id = p.id
          WHERE t.created_at >= ? AND t.created_at <= ?
            AND t.is_hold = 0
            AND t.is_refunded = 0
          GROUP BY ti.product_id
          ORDER BY total_qty DESC
      """, [start, end]);

      return result;
  }


  // Emergency Product and Local Staging functions removed

  static const String _syncLockKey = 'sync_lock_expires_ms';

  Future<void> _ensureAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Cross-isolate friendly sync mutex (foreground + Workmanager).
  Future<bool> tryAcquireSyncLock({
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final db = await database;
    await _ensureAppSettingsTable(db);
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_syncLockKey],
    );
    if (rows.isNotEmpty) {
      final expires =
          int.tryParse(rows.first['value']?.toString() ?? '0') ?? 0;
      if (expires > now) return false;
    }
    await db.insert(
      'app_settings',
      {
        'key': _syncLockKey,
        'value': '${now + ttl.inMilliseconds}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<void> releaseSyncLock() async {
    final db = await database;
    await _ensureAppSettingsTable(db);
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_syncLockKey],
    );
  }
}

