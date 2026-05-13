class Product {
  final int id;
  final String name;
  final double price;
  final double discountNominal;
  final int? categoryId;
  final int? brandId;
  final String? imageUrl;
  final String? sku;
  final String? localImagePath;

  final bool isFeatured;
  final int needsLabel;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.discountNominal = 0,
    this.categoryId,
    this.brandId,
    this.imageUrl,
    this.sku,
    this.localImagePath,
    this.isFeatured = false,
    this.needsLabel = 0,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] ?? map['price_dinein'] as num).toDouble(),
      discountNominal: (map['discount_nominal'] != null) ? (map['discount_nominal'] as num).toDouble() : 0.0,
      categoryId: map['category_id'],
      brandId: map['brand_id'],
      imageUrl: map['image_url'],
      sku: map['sku'],
      localImagePath: map['local_image_path'],
      isFeatured: (map['is_featured'] == 1 || map['is_featured'] == true),
      needsLabel: map['needs_label'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'discount_nominal': discountNominal,
      'category_id': categoryId,
      'brand_id': brandId,
      'image_url': imageUrl,
      'sku': sku,
      'local_image_path': localImagePath,
      'is_featured': isFeatured ? 1 : 0,
      'needs_label': needsLabel,
    };
  }
}

class Category {
    final int id;
    final String name;
    
    Category({required this.id, required this.name});
    
    factory Category.fromMap(Map<String, dynamic> map) {
        return Category(id: map['id'], name: map['name']);
    }
}

class ResTable {
    final int id;
    final int businessId;
    final int locationId;
    final String name;
    final String? description;
    
    ResTable({
        required this.id,
        required this.businessId,
        required this.locationId,
        required this.name,
        this.description,
    });
    
    factory ResTable.fromMap(Map<String, dynamic> map) {
        return ResTable(
            id: map['id'],
            businessId: map['business_id'],
            locationId: map['location_id'],
            name: map['name'],
            description: map['description'],
        );
    }
}

class AppUser {
    final int id;
    final String username;
    final String firstName;
    final String? lastName;
    final String? pin;
    final String? profileImage;
    final int isWaiter;
    final int isAdmin;
    
    AppUser({required this.id, required this.username, required this.firstName, this.lastName, this.pin, this.profileImage, this.isWaiter = 0, this.isAdmin = 0});
    
    factory AppUser.fromMap(Map<String, dynamic> map) {
        return AppUser(
            id: map['id'],
            username: map['username'],
            firstName: map['first_name'],
            lastName: map['last_name'],
            pin: map['pin'],
            profileImage: map['profile_image'],
            isWaiter: map['is_waiter'] ?? 0,
            isAdmin: map['is_admin'] ?? 0,
        );
    }
}

class CartItem {
  final Product product;
  int qty;
  double price;
  String note;
  double itemDiscount;

  CartItem({
    required this.product,
    this.qty = 1,
    required this.price,
    this.note = '',
    this.selectedModifiers = const [],
    this.itemDiscount = 0,
  });

  final List<ModifierOption> selectedModifiers;

  double get totalPricePerItem {
    double modTotal = 0;
    for (var mod in selectedModifiers) {
      modTotal += mod.price;
    }
    return price + modTotal;
  }

  double get total => totalPricePerItem * qty;
}

class Tax {
    final int id;
    final String name;
    final double amount;
    
    Tax({required this.id, required this.name, required this.amount});
    
    factory Tax.fromMap(Map<String, dynamic> map) {
        return Tax(id: map['id'], name: map['name'], amount: (map['amount'] as num).toDouble());
    }
}

class Discount {
    final int id;
    final String name;
    final String type; // fixed or percentage
    final double amount;
    final int priority;
    final String? startsAt;
    final String? endsAt;
    final int? brandId;
    final int? categoryId;
    final String? spg;
    List<int> applicableVariations;

    Discount({
        required this.id, 
        required this.name, 
        required this.type, 
        required this.amount, 
        this.priority = 0,
        this.startsAt,
        this.endsAt,
        this.brandId,
        this.categoryId,
        this.spg,
        this.applicableVariations = const []
    });

    factory Discount.fromMap(Map<String, dynamic> map) {
        return Discount(
            id: map['id'],
            name: map['name'],
            type: map['type'],
            amount: (map['amount'] as num).toDouble(),
            priority: map['priority'] ?? 0,
            startsAt: map['starts_at'],
            endsAt: map['ends_at'],
            brandId: map['brand_id'],
            categoryId: map['category_id'],
            spg: map['spg']
        );
    }
}

class ProductModifier {
  final int id;
  final String name;
  final String type;
  final List<ModifierOption> options;

  ProductModifier({
    required this.id,
    required this.name,
    required this.type,
    this.options = const [],
  });
}

class ModifierOption {
  final int id;
  final int setId;
  final String name;
  final double price;

  ModifierOption({
    required this.id,
    required this.setId,
    required this.name,
    required this.price,
  });

  factory ModifierOption.fromMap(Map<String, dynamic> map) {
    return ModifierOption(
      id: map['id'],
      setId: map['modifier_set_id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
    );
  }

  ModifierOption copyWith({
    int? id,
    int? setId,
    String? name,
    double? price,
  }) {
    return ModifierOption(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}

class PosTransaction {
  final int? id;
  final String? invoiceNo;
  final String saleType;
  final int? tableId;
  final double subtotal;
  final double discount;
  final double manualDiscount;
  final double tax;
  final double total;
  final String status;
  final bool isHold;
  final String? holdNote;
  final DateTime createdAt;
  final String paymentMethod;
  final int? cashierId;
  final String cashierName;
  final int? customerId;
  final String? customerName;
  final double amountPaid;
  final double changeAmount;
  final int? resServiceStaffId;
  final int pax;
  final int shiftId;
  final List<PosTransactionItem> items;
  final List<PosTransactionPayment> payments;

  PosTransaction({
    this.id,
    this.invoiceNo,
    required this.saleType,
    this.tableId,
    required this.subtotal,
    required this.discount,
    required this.manualDiscount,
    required this.tax,
    required this.total,
    this.status = 'final',
    this.isHold = false,
    this.holdNote,
    required this.createdAt,
    required this.paymentMethod,
    this.cashierId,
    required this.cashierName,
    this.customerId,
    this.customerName,
    required this.amountPaid,
    required this.changeAmount,
    this.resServiceStaffId,
    this.pax = 0,
    this.shiftId = 1,
    required this.items,
    this.payments = const [],
  });

  Map<String, dynamic> toHeaderMap() {
    return {
      if (id != null) 'id': id,
      'sale_type': saleType,
      'res_table_id': tableId,
      'subtotal': subtotal,
      'discount': discount,
      'manual_discount': manualDiscount,
      'tax': tax,
      'total': total,
      'status': status,
      'is_hold': isHold ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'payment_method': paymentMethod,
      'cashier_id': cashierId,
      'cashier_name': cashierName,
      'customer_id': customerId,
      'customer_name': customerName ?? 'Umum',
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'res_service_staff_id': resServiceStaffId,
      'pax': pax,
      'shift_id': shiftId,
      'is_closed': 0,
      'synced': 0,
      'invoice_no': invoiceNo,
      'hold_note': holdNote,
    };
  }
}

class PosTransactionItem {
  final int productId;
  final int qty;
  final double price;
  final double discount;
  final String note;
  final List<PosTransactionModifier> modifiers;

  PosTransactionItem({
    required this.productId,
    required this.qty,
    required this.price,
    this.discount = 0.0,
    this.note = '',
    this.modifiers = const [],
  });

  Map<String, dynamic> toMap(int txId) {
    return {
      'transaction_id': txId,
      'product_id': productId,
      'qty': qty,
      'price': price,
      'discount': discount,
      'note': note,
    };
  }
}

class PosTransactionModifier {
  final int optionId;
  final String name;
  final double price;

  PosTransactionModifier({
    required this.optionId,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap(int itemId) {
    return {
      'transaction_item_id': itemId,
      'modifier_option_id': optionId,
      'modifier_name': name,
      'price': price,
    };
  }
}

class PosTransactionPayment {
  final String method;
  final double amount;
  final String note;

  PosTransactionPayment({
    required this.method,
    required this.amount,
    this.note = '',
  });

  Map<String, dynamic> toMap(int txId) {
    return {
      'transaction_id': txId,
      'method': method,
      'amount': amount,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class LocalProduct {
  final int? id;
  final String name;
  final String? unitName;
  final String? sku;
  final double purchasePrice;
  final double sellingPrice;
  final int enableStock;
  final double alertQuantity;
  final String taxType; // inclusive or exclusive
  final String productType; // single
  final String? imagePath;
  final String? categoryName;
  final String? brandName;
  final int isTransferredLocal;
  final int isTransferredServer;
  final int? serverId;
  final DateTime? createdAt;

  LocalProduct({
    this.id,
    required this.name,
    this.unitName,
    this.sku,
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.enableStock = 1,
    this.alertQuantity = 0,
    this.taxType = 'inclusive',
    this.productType = 'single',
    this.imagePath,
    this.categoryName,
    this.brandName,
    this.isTransferredLocal = 0,
    this.isTransferredServer = 0,
    this.serverId,
    this.createdAt,
  });

  factory LocalProduct.fromMap(Map<String, dynamic> map) {
    return LocalProduct(
      id: map['id'],
      name: map['name'],
      unitName: map['unit_name'],
      sku: map['sku'],
      purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      enableStock: map['enable_stock'] ?? 1,
      alertQuantity: (map['alert_quantity'] as num?)?.toDouble() ?? 0.0,
      taxType: map['tax_type'] ?? 'inclusive',
      productType: map['product_type'] ?? 'single',
      imagePath: map['image_path'],
      categoryName: map['category_name'],
      brandName: map['brand_name'],
      isTransferredLocal: map['is_transferred_local'] ?? 0,
      isTransferredServer: map['is_transferred_server'] ?? 0,
      serverId: map['server_id'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'unit_name': unitName,
      'sku': sku,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'enable_stock': enableStock,
      'alert_quantity': alertQuantity,
      'tax_type': taxType,
      'product_type': productType,
      'image_path': imagePath,
      'category_name': categoryName,
      'brand_name': brandName,
      'is_transferred_local': isTransferredLocal,
      'is_transferred_server': isTransferredServer,
      'server_id': serverId,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}
