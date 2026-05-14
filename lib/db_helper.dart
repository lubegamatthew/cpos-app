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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        buyPrice REAL NOT NULL,
        sellPrice REAL NOT NULL,
        unit TEXT DEFAULT 'pcs',
        description TEXT DEFAULT '',
        createdAt TEXT NOT NULL
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
  }

  Future<void> insertInventoryItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      'inventory',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAllInventoryItems(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'inventory',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAllInventoryItems() async {
    final db = await database;
    return await db.query('inventory', orderBy: 'name ASC');
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
    await db.update(
      'inventory',
      item,
      where: 'id = ?',
      whereArgs: [item['id']],
    );
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