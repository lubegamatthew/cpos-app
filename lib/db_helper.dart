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
      CREATE TABLE orders (
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
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        inventoryId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        buyPrice REAL NOT NULL,
        sellPrice REAL NOT NULL,
        totalCost REAL NOT NULL,
        totalRevenue REAL NOT NULL,
        profit REAL NOT NULL,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (inventoryId) REFERENCES inventory (id)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE orders (
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
        CREATE TABLE order_items (
          id TEXT PRIMARY KEY,
          orderId TEXT NOT NULL,
          inventoryId TEXT NOT NULL,
          itemName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          buyPrice REAL NOT NULL,
          sellPrice REAL NOT NULL,
          totalCost REAL NOT NULL,
          totalRevenue REAL NOT NULL,
          profit REAL NOT NULL,
          FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE,
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

  // Orders methods
  Future<void> insertOrder(Map<String, dynamic> order) async {
    final db = await database;
    await db.insert(
      'orders',
      order,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrderItem(Map<String, dynamic> orderItem) async {
    final db = await database;
    await db.insert(
      'order_items',
      orderItem,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await database;
    return await db.query(
      'orders',
      orderBy: 'createdAt DESC',
    );
  }

  Future<Map<String, dynamic>?> getOrder(String id) async {
    final db = await database;
    final results = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final db = await database;
    return await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
  }

  Future<void> deleteOrder(String id) async {
    final db = await database;
    await db.delete(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final db = await database;
    await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}