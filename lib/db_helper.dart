import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cpos.db');
    return _database!;
  }

Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Create categories table first
    await db.execute('''
      CREATE TABLE categories (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL UNIQUE,
        description TEXT DEFAULT '',
        createdAt   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        categoryId  TEXT NOT NULL,
        quantity    INTEGER NOT NULL,
        buyPrice    REAL NOT NULL,
        sellPrice   REAL NOT NULL,
        unit        TEXT DEFAULT 'pcs',
        description TEXT DEFAULT '',
        createdAt   TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          customerName TEXT DEFAULT 'Walk-in Customer',
          customerPhone TEXT DEFAULT '',
          totalAmount REAL NOT NULL,
          totalProfit REAL NOT NULL,
          paymentMethod TEXT DEFAULT 'Cash',
          status TEXT DEFAULT 'Completed',
          notes TEXT DEFAULT '',
          createdAt TEXT NOT NULL
        )
      ''');

    await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          saleId TEXT NOT NULL,
          inventoryId TEXT NOT NULL,
          itemName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          buyPrice REAL NOT NULL,
          sellPrice REAL NOT NULL,
          totalCost REAL NOT NULL,
          totalRevenue REAL NOT NULL,
          profit REAL NOT NULL,
          FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE,
          FOREIGN KEY (inventoryId) REFERENCES inventory (id)
        )
      ''');
  }

Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          customerName TEXT DEFAULT 'Walk-in Customer',
          customerPhone TEXT DEFAULT '',
          totalAmount REAL NOT NULL,
          totalProfit REAL NOT NULL,
          paymentMethod TEXT DEFAULT 'Cash',
          status TEXT DEFAULT 'Completed',
          notes TEXT DEFAULT '',
          createdAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          saleId TEXT NOT NULL,
          inventoryId TEXT NOT NULL,
          itemName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          buyPrice REAL NOT NULL,
          sellPrice REAL NOT NULL,
          totalCost REAL NOT NULL,
          totalRevenue REAL NOT NULL,
          profit REAL NOT NULL,
          FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE,
          FOREIGN KEY (inventoryId) REFERENCES inventory (id)
        )
      ''');
    }

    if (oldVersion < 3) {
      // Migrate from orders/order_items to sales/sale_items
      await db.execute('DROP TABLE IF EXISTS sales');
      await db.execute('DROP TABLE IF EXISTS sale_items');

      // Rename existing tables first, then rebuild with new column names
      final tableInfo = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='orders'");
      if (tableInfo.isNotEmpty) {
        await db.execute('ALTER TABLE orders RENAME TO sales');
      } else {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales (
            id TEXT PRIMARY KEY,
            customerName TEXT DEFAULT 'Walk-in Customer',
            customerPhone TEXT DEFAULT '',
            totalAmount REAL NOT NULL,
            totalProfit REAL NOT NULL,
            paymentMethod TEXT DEFAULT 'Cash',
            status TEXT DEFAULT 'Completed',
            notes TEXT DEFAULT '',
            createdAt TEXT NOT NULL
          )
        ''');
      }

      final orderItemsTableInfo = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='order_items'");
      if (orderItemsTableInfo.isNotEmpty) {
        // Create temp table with new schema (saleId instead of orderId)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sale_items_temp (
            id TEXT PRIMARY KEY,
            saleId TEXT NOT NULL,
            inventoryId TEXT NOT NULL,
            itemName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            buyPrice REAL NOT NULL,
            sellPrice REAL NOT NULL,
            totalCost REAL NOT NULL,
            totalRevenue REAL NOT NULL,
            profit REAL NOT NULL,
            FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE,
            FOREIGN KEY (inventoryId) REFERENCES inventory (id)
          )
        ''');
        // Copy data with column rename: orderId -> saleId
        await db.execute('''
          INSERT INTO sale_items_temp(id, saleId, inventoryId, itemName, quantity, buyPrice, sellPrice, totalCost, totalRevenue, profit)
          SELECT id, orderId, inventoryId, itemName, quantity, buyPrice, sellPrice, totalCost, totalRevenue, profit FROM order_items
        ''');
        await db.execute('DROP TABLE order_items');
        await db.execute('ALTER TABLE sale_items_temp RENAME TO sale_items');
      } else {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sale_items (
            id TEXT PRIMARY KEY,
            saleId TEXT NOT NULL,
            inventoryId TEXT NOT NULL,
            itemName TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            buyPrice REAL NOT NULL,
            sellPrice REAL NOT NULL,
            totalCost REAL NOT NULL,
            totalRevenue REAL NOT NULL,
            profit REAL NOT NULL,
            FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE,
            FOREIGN KEY (inventoryId) REFERENCES inventory (id)
          )
        ''');
      }
    }

    if (oldVersion < 4) {
      // Migration to add categories table and convert category TEXT to categoryId foreign key
      await _migrateToCategoriesTable(db);
    }
  }

  Future<void> _migrateToCategoriesTable(Database db) async {
    // Step 1: Get all existing inventory items
    final inventoryItems = await db.query('inventory');

    // Step 2: Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL UNIQUE,
        description TEXT DEFAULT '',
        createdAt   TEXT NOT NULL
      )
    ''');

    // Step 3: Extract unique categories and create category records
    final uniqueCategories = <String>{};
    for (final item in inventoryItems) {
      final categoryName = item['category'] as String? ?? 'Uncategorized';
      uniqueCategories.add(categoryName);
    }

    // Insert categories
    final now = DateTime.now().toIso8601String();
    for (final categoryName in uniqueCategories) {
      await db.insert(
        'categories',
        {
          'id': 'CAT-${DateTime.now().millisecondsSinceEpoch}-${uniqueCategories.toList().indexOf(categoryName)}',
          'name': categoryName,
          'description': '',
          'createdAt': now,
        },
      );
    }

    // Step 4: Create new inventory table with categoryId foreign key
    await db.execute('''
      CREATE TABLE inventory_new (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        categoryId  TEXT NOT NULL,
        quantity    INTEGER NOT NULL,
        buyPrice    REAL NOT NULL,
        sellPrice   REAL NOT NULL,
        unit        TEXT DEFAULT 'pcs',
        description TEXT DEFAULT '',
        createdAt   TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');

    // Step 5: Migrate data - map category names to category IDs
    final categoriesMap = <String, String>{}; // categoryName -> categoryId
    final allCategories = await db.query('categories');
    for (final cat in allCategories) {
      categoriesMap[cat['name'] as String] = cat['id'] as String;
    }

    for (final item in inventoryItems) {
      final categoryName = item['category'] as String? ?? 'Uncategorized';
      final categoryId = categoriesMap[categoryName] ?? 'CAT-DEFAULT';

      await db.insert('inventory_new', {
        'id': item['id'],
        'name': item['name'],
        'categoryId': categoryId,
        'quantity': item['quantity'],
        'buyPrice': item['buyPrice'],
        'sellPrice': item['sellPrice'],
        'unit': item['unit'] ?? 'pcs',
        'description': item['description'] ?? '',
        'createdAt': item['createdAt'],
      });
    }

    // Step 6: Drop old table and rename new table
    await db.execute('DROP TABLE inventory');
    await db.execute('ALTER TABLE inventory_new RENAME TO inventory');
  }

  Future<void> insertInventoryItem(Map<String, dynamic> item) async {
    final db = await database;
    final categoryName = item['category'] as String? ?? 'Uncategorized';
    
    // Ensure category exists and get its ID
    await ensureCategoryExists(categoryName);
    final categoryId = await getCategoryIdByName(categoryName);
    
    if (categoryId == null) {
      throw Exception('Failed to create/find category: $categoryName');
    }

    await db.insert(
      'inventory',
      {
        'id': item['id'],
        'name': item['name'],
        'categoryId': categoryId,
        'quantity': item['quantity'],
        'buyPrice': item['buyPrice'],
        'sellPrice': item['sellPrice'],
        'unit': item['unit'] ?? 'pcs',
        'description': item['description'] ?? '',
        'createdAt': item['createdAt'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAllInventoryItems(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    
    for (final item in items) {
      final categoryName = item['category'] as String? ?? 'Uncategorized';
      
      // Ensure category exists and get its ID
      await ensureCategoryExists(categoryName);
      final categoryId = await getCategoryIdByName(categoryName);
      
      if (categoryId == null) {
        throw Exception('Failed to create/find category: $categoryName');
      }

      batch.insert(
        'inventory',
        {
          'id': item['id'],
          'name': item['name'],
          'categoryId': categoryId,
          'quantity': item['quantity'],
          'buyPrice': item['buyPrice'],
          'sellPrice': item['sellPrice'],
          'unit': item['unit'] ?? 'pcs',
          'description': item['description'] ?? '',
          'createdAt': item['createdAt'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAllInventoryItems() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT i.*, c.name as category
      FROM inventory i
      LEFT JOIN categories c ON i.categoryId = c.id
      ORDER BY i.name ASC
    ''');
  }

  Future<int> getCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM inventory');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearInventory() async {
    final db = await database;
    await db.delete('inventory');
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete(
      'inventory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateItem(Map<String, dynamic> item) async {
    final db = await database;
    
    // If item contains 'category' field, convert to categoryId
    if (item.containsKey('category')) {
      final categoryName = item['category'] as String? ?? 'Uncategorized';
      await ensureCategoryExists(categoryName);
      final categoryId = await getCategoryIdByName(categoryName);
      
      if (categoryId == null) {
        throw Exception('Failed to find/create category: $categoryName');
      }

      item = Map<String, dynamic>.from(item);
      item['categoryId'] = categoryId;
      item.remove('category');
    }

    await db.update(
      'inventory',
      item,
      where: 'id = ?',
      whereArgs: [item['id']],
    );
  }

  // Categories methods
  Future<void> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await database;
    return await db.query(
      'categories',
      orderBy: 'name ASC',
    );
  }

  Future<Map<String, dynamic>?> getCategory(String id) async {
    final db = await database;
    final results = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateCategory(Map<String, dynamic> category) async {
    final db = await database;
    await db.update(
      'categories',
      category,
      where: 'id = ?',
      whereArgs: [category['id']],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    // Check if category is in use
    final itemsUsingCategory = await db.query(
      'inventory',
      where: 'categoryId = ?',
      whereArgs: [id],
    );

    if (itemsUsingCategory.isNotEmpty) {
      throw Exception('Cannot delete category: ${itemsUsingCategory.length} item(s) are using this category');
    }

    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getCategoryIdByName(String name) async {
    final db = await database;
    final results = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
    return results.isNotEmpty ? results.first['id'] as String : null;
  }

  Future<void> ensureCategoryExists(String categoryName) async {
    final existingId = await getCategoryIdByName(categoryName);
    if (existingId == null) {
      final newId = 'CAT-${DateTime.now().millisecondsSinceEpoch}';
      await insertCategory({
        'id': newId,
        'name': categoryName,
        'description': '',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

// Sales methods
  Future<void> insertSale(Map<String, dynamic> sale) async {
     final db = await database;
     await db.insert(
       'sales',
       sale,
       conflictAlgorithm: ConflictAlgorithm.replace,
     );
   }

  Future<void> insertSaleItem(Map<String, dynamic> saleItem) async {
     final db = await database;
     await db.insert(
       'sale_items',
       saleItem,
       conflictAlgorithm: ConflictAlgorithm.replace,
     );
   }

 Future<List<Map<String, dynamic>>> getAllSales() async {
      final db = await database;
      return await db.query(
        'sales',
        orderBy: 'createdAt DESC',
      );
    }

    Future<List<Map<String, dynamic>>> getSalesWithItems({String? filter}) async {
       final db = await database;
       String whereClause = '';
       List<dynamic> whereArgs = [];

       if (filter != null) {
         final now = DateTime.now();
         DateTime startDate;

         switch (filter) {
           case 'today':
             startDate = DateTime(now.year, now.month, now.day);
             break;
           case 'week':
             startDate = now.subtract(Duration(days: now.weekday - 1));
             startDate = DateTime(startDate.year, startDate.month, startDate.day);
             break;
           case 'month':
             startDate = DateTime(now.year, now.month, 1);
             break;
           default:
             startDate = DateTime(1970);
         }

         if (filter != 'all') {
           whereClause = 'createdAt >= ?';
           whereArgs.add(startDate.toIso8601String());
         }
       }

       final sales = await db.query(
         'sales',
         where: whereClause.isEmpty ? null : whereClause,
         whereArgs: whereArgs.isEmpty ? null : whereArgs,
         orderBy: 'createdAt DESC',
       );

       final List<Map<String, dynamic>> result = [];
       for (final sale in sales) {
         final items = await db.query(
           'sale_items',
           where: 'saleId = ?',
           whereArgs: [sale['id']],
         );
         result.add({
           'sale': sale,
           'items': items,
         });
       }
       return result;
     }

   Future<Map<String, dynamic>?> getSale(String id) async {
     final db = await database;
     final results = await db.query(
       'sales',
       where: 'id = ?',
       whereArgs: [id],
     );
     return results.isNotEmpty ? results.first : null;
   }

   Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
     final db = await database;
     return await db.query(
       'sale_items',
       where: 'saleId = ?',
       whereArgs: [saleId],
       orderBy: 'id ASC',
     );
   }

   Future<void> deleteSale(String id) async {
     final db = await database;
     await db.delete(
       'sale_items',
       where: 'saleId = ?',
       whereArgs: [id],
     );
     await db.delete(
       'sales',
       where: 'id = ?',
       whereArgs: [id],
     );
   }

   Future<void> updateSaleStatus(String saleId, String status) async {
     final db = await database;
     await db.update(
       'sales',
       {'status': status},
       where: 'id = ?',
       whereArgs: [saleId],
     );
   }
}