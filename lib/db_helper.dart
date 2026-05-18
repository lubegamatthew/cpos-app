import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // ── Schema version (bump whenever _createDB or _upgradeDB changes) ──
  static const int _kSchemaVersion = 5;

  // ── Current DB file name ────────────────────────────────────────────
  static const String _kDbFileName = 'cpos.db';
  static const String _kLastSyncKey = 'last_sync_timestamp';

  // ── Singleton ──────────────────────────────────────────────────────
  static final DatabaseHelper _instance = DatabaseHelper._init();
  static Database? _db;
  static DatabaseHelper get instance => _instance;

  DatabaseHelper._init();

  // ── Database initialiser ────────────────────────────────────────────
  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final dbPath = join(dbDir, _kDbFileName);
    _db = await openDatabase(
      dbPath,
      version: _kSchemaVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
    return _db!;
  }

  // ════════════════════════════════════════════════════════════════════════
  // TABLE CREATION / MIGRATION
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _createDB(Database db, int version) async {
    await _createCoreTables(db);
    await db.execute(_kSyncQueueDDL);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Version 1 → 2  (database born at v2 already, guard for safety)
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id            TEXT    PRIMARY KEY,
          customerName  TEXT    DEFAULT 'Walk-in Customer',
          customerPhone TEXT    DEFAULT '',
          totalAmount   REAL    NOT NULL,
          totalProfit   REAL    NOT NULL,
          paymentMethod TEXT    DEFAULT 'Cash',
          status        TEXT    DEFAULT 'Completed',
          notes         TEXT    DEFAULT '',
          createdAt     TEXT    NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_items (
          id          TEXT    PRIMARY KEY,
          saleId      TEXT    NOT NULL,
          inventoryId TEXT    NOT NULL,
          itemName    TEXT    NOT NULL,
          quantity    INTEGER NOT NULL,
          buyPrice    REAL    NOT NULL,
          sellPrice   REAL    NOT NULL,
          totalCost   REAL    NOT NULL,
          totalRevenue REAL   NOT NULL,
          profit      REAL    NOT NULL,
          FOREIGN KEY (saleId)      REFERENCES sales      (id) ON DELETE CASCADE,
          FOREIGN KEY (inventoryId) REFERENCES inventory  (id)
        )
      ''');
    }

    // v2 → v3: rename orders → sales, order_items → sale_items
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS sales');
      await db.execute('DROP TABLE IF EXISTS sale_items');
      final hasOrders = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name='orders'",
      );
      if (hasOrders.isNotEmpty) {
        await db.execute('ALTER TABLE orders RENAME TO sales');
        await db.execute('ALTER TABLE order_items RENAME TO sale_items');
      } else {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sales (
            id            TEXT    PRIMARY KEY,
            customerName  TEXT    DEFAULT 'Walk-in Customer',
            customerPhone TEXT    DEFAULT '',
            totalAmount   REAL    NOT NULL,
            totalProfit   REAL    NOT NULL,
            paymentMethod TEXT    DEFAULT 'Cash',
            status        TEXT    DEFAULT 'Completed',
            notes         TEXT    DEFAULT '',
            createdAt     TEXT    NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sale_items (
            id          TEXT    PRIMARY KEY,
            saleId      TEXT    NOT NULL,
            inventoryId TEXT    NOT NULL,
            itemName    TEXT    NOT NULL,
            quantity    INTEGER NOT NULL,
            buyPrice    REAL    NOT NULL,
            sellPrice   REAL    NOT NULL,
            totalCost   REAL    NOT NULL,
            totalRevenue REAL   NOT NULL,
            profit      REAL    NOT NULL,
            FOREIGN KEY (saleId)      REFERENCES sales      (id) ON DELETE CASCADE,
            FOREIGN KEY (inventoryId) REFERENCES inventory  (id)
          )
        ''');
      }
      await db.execute(
        'ALTER TABLE sale_items RENAME COLUMN orderId TO saleId',
      );
    }

    // v3 → v4: introduce categories table
    if (oldVersion < 4) {
      await _migrateToCategoriesTable(db);
    }

    // v4 → v5: add sync_queue table
    if (oldVersion < 5) {
      await db.execute(_kSyncQueueDDL);
    }
  }

  static const String _kSyncQueueDDL = '''
    CREATE TABLE IF NOT EXISTS sync_queue (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT    NOT NULL,
      action     TEXT    NOT NULL,
      data_json  TEXT    NOT NULL,
      status     TEXT    NOT NULL DEFAULT 'pending',
      created_at TEXT    NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_sync_queue_status
      ON sync_queue (status);
  ''';

  Future<void> _createCoreTables(Database db) async {
    // Categories ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE categories (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL UNIQUE,
        description TEXT    DEFAULT '',
        createdAt   TEXT    NOT NULL
      )
    ''');

    // Inventory ───────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE inventory (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        categoryId  TEXT    NOT NULL,
        quantity    INTEGER NOT NULL,
        buyPrice    REAL    NOT NULL,
        sellPrice   REAL    NOT NULL,
        unit        TEXT    DEFAULT 'pcs',
        description TEXT    DEFAULT '',
        createdAt   TEXT    NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');

    // Sales ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE sales (
        id            TEXT    PRIMARY KEY,
        customerName  TEXT    DEFAULT 'Walk-in Customer',
        customerPhone TEXT    DEFAULT '',
        totalAmount   REAL    NOT NULL,
        totalProfit   REAL    NOT NULL,
        paymentMethod TEXT    DEFAULT 'Cash',
        status        TEXT    DEFAULT 'Completed',
        notes         TEXT    DEFAULT '',
        createdAt     TEXT    NOT NULL
      )
    ''');

    // Sale items ─────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE sale_items (
        id          TEXT    PRIMARY KEY,
        saleId      TEXT    NOT NULL,
        inventoryId TEXT    NOT NULL,
        itemName    TEXT    NOT NULL,
        quantity    INTEGER NOT NULL,
        buyPrice    REAL    NOT NULL,
        sellPrice   REAL    NOT NULL,
        totalCost   REAL    NOT NULL,
        totalRevenue REAL   NOT NULL,
        profit      REAL    NOT NULL,
        FOREIGN KEY (saleId)      REFERENCES sales     (id) ON DELETE CASCADE,
        FOREIGN KEY (inventoryId) REFERENCES inventory (id)
      )
    ''');
  }

  // ════════════════════════════════════════════════════════════════════════
  // CATEGORIES MIGRATION HELPER (v3 → v4)
  // ════════════════════════════════════════════════════════════════════════
  Future<void> _migrateToCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL UNIQUE,
        description TEXT    DEFAULT '',
        createdAt   TEXT    NOT NULL
      )
    ''');
    final inventoryRows = await db.query('inventory');
    final uniqueNames = <String>{};
    for (final row in inventoryRows) {
      final existingCol = row['category'];
      if (existingCol != null) {
        uniqueNames.add(existingCol.toString());
      }
    }
    final now = DateTime.now().toIso8601String();
    for (final catName in uniqueNames) {
      await db.insert('categories', {
        'id':          'CAT-${DateTime.now().millisecondsSinceEpoch}',
        'name':        catName,
        'description': '',
        'createdAt':   now,
      });
    }
    await db.execute('''
      CREATE TABLE inventory_new (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        categoryId  TEXT    NOT NULL,
        quantity    INTEGER NOT NULL,
        buyPrice    REAL    NOT NULL,
        sellPrice   REAL    NOT NULL,
        unit        TEXT    DEFAULT 'pcs',
        description TEXT    DEFAULT '',
        createdAt   TEXT    NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE RESTRICT
      )
    ''');
    final catMap = <String, String>{};
    for (final c in await db.query('categories')) {
      catMap[c['name'] as String] = c['id'] as String;
    }
    for (final item in inventoryRows) {
      final rawName = (item['category'] as String?) ?? 'Uncategorized';
      await db.insert('inventory_new', {
        'id':          item['id'],
        'name':        item['name'],
        'categoryId':  catMap[rawName] ?? 'CAT-DEFAULT',
        'quantity':    item['quantity'],
        'buyPrice':    item['buyPrice'],
        'sellPrice':   item['sellPrice'],
        'unit':        item['unit']              ?? 'pcs',
        'description': item['description']       ?? '',
        'createdAt':   item['createdAt'],
      });
    }
    await db.execute('DROP TABLE inventory');
    await db.execute('ALTER TABLE inventory_new RENAME TO inventory');
  }

  // ════════════════════════════════════════════════════════════════════════
  // INVENTORY
  // ════════════════════════════════════════════════════════════════════════

  Future<void> insertInventoryItem(Map<String, dynamic> item) async {
    final db = await database;
    final catName  = item['category']  as String? ?? 'Uncategorized';
    final categoryId = await _getCategoryIdByName(catName);
    if (categoryId == null) {
      throw Exception(
      'Category "$catName" not found. Create it first.');
    }
    await db.insert(
      'inventory',
      {
        'id':          item['id'],
        'name':        item['name'],
        'categoryId':  categoryId,
        'quantity':    item['quantity'],
        'buyPrice':    item['buyPrice'],
        'sellPrice':   item['sellPrice'],
        'unit':        item['unit']      ?? 'pcs',
        'description': item['description'] ?? '',
        'createdAt':   item['createdAt'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAllInventoryItems(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final db = await database;

    // 1. Collect all distinct category names
    final catNames = <String>{};
    for (final item in items) {
      final c = item['category'] as String?;
      if (c != null && c.isNotEmpty) catNames.add(c);
    }
    if (catNames.isEmpty) {
      // No categories → all items go through as-is
      final batch = db.batch();
      for (final item in items) {
        batch.insert('inventory', _inventoryRowMap(item),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      return;
    }

    // 2. Find which categories already exist (one query)
    final existing = <String, String>{};
    for (final c in await db.query('categories', columns: ['id', 'name'])) {
      existing[c['name'] as String] = c['id'] as String;
    }

    // 3. Build name→id for new categories and persist in one batch
    final namesToCreate = catNames.where((n) => !existing.containsKey(n)).toList();
    final nameToId      = Map<String, String>.from(existing);

    if (namesToCreate.isNotEmpty) {
      final batch = db.batch();
      for (final n in namesToCreate) {
        final newId = 'CAT-${DateTime.now().millisecondsSinceEpoch}-${n.hashCode}';
        batch.insert('categories', {
          'id':          newId,
          'name':        n,
          'description': '',
          'createdAt':   DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        nameToId[n] = newId;
      }
      await batch.commit(noResult: true);
    }

    // 4. Bulk-insert inventory rows
    final batch = db.batch();
    for (final item in items) {
      batch.insert('inventory', _inventoryRowMap(item, nameToId: nameToId),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _inventoryRowMap(
    Map<String, dynamic> item, {
    Map<String, String>? nameToId,
  }) {
    final catName    = item['category'] as String? ?? 'Uncategorized';
    final categoryId = nameToId != null
        ? (nameToId[catName] ?? _fallbackCategoryId(catName, nameToId))
        : 'CAT-UNKNOWN';
    return {
      'id':          item['id'],
      'name':        item['name'],
      'categoryId':  categoryId,
      'quantity':    item['quantity'],
      'buyPrice':    item['buyPrice'],
      'sellPrice':   item['sellPrice'],
      'unit':        item['unit']      ?? 'pcs',
      'description': item['description'] ?? '',
      'createdAt':   item['createdAt'],
    };
  }

  String _fallbackCategoryId(String name, Map<String, String> nameToId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id  = 'CAT-$now-${name.hashCode}';
    nameToId[name] = id;
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllInventoryItems() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT i.*, c.name AS category
      FROM inventory i
      LEFT JOIN categories c ON i.categoryId = c.id
      ORDER BY i.name ASC
    ''');
  }

  Future<int> getCount() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) FROM inventory');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<void> clearInventory() async {
    final db = await database;
    await db.delete('inventory');
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateItem(Map<String, dynamic> item) async {
    final db = await database;
    var data = Map<String, dynamic>.from(item);
    if (data.containsKey('category')) {
      final catName     = data['category'] as String? ?? 'Uncategorized';
      final categoryId  = await _getCategoryIdByName(catName);
      if (categoryId == null) {
        throw Exception('Category "$catName" not found.');
      }
      data['categoryId'] = categoryId;
      data.remove('category');
    }
    await db.update(
      'inventory',
      data,
      where: 'id = ?',
      whereArgs: [data['id']],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // CATEGORIES
  // ════════════════════════════════════════════════════════════════════════

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
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getCategory(String id) async {
    final db = await database;
    final r = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
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
    final inUse = await db.query(
      'inventory', where: 'categoryId = ?', whereArgs: [id]);
    if (inUse.isNotEmpty) {
      throw Exception(
      'Cannot delete category: ${inUse.length} item(s) are using it.');
    }
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> _getCategoryIdByName(String name) async {
    final db = await database;
    final r = await db.query(
      'categories', where: 'name = ?', whereArgs: [name]);
    return r.isNotEmpty ? r.first['id'] as String : null;
  }

  Future<void> ensureCategoryExists(String categoryName) async {
    final existing = await _getCategoryIdByName(categoryName);
    if (existing == null) {
      await insertCategory({
        'id':          'CAT-${DateTime.now().millisecondsSinceEpoch}',
        'name':        categoryName,
        'description': '',
        'createdAt':   DateTime.now().toIso8601String(),
      });
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // SALES
  // ════════════════════════════════════════════════════════════════════════

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
    return await db.query('sales', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getSalesWithItems({String? filter}) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;
    if (filter != null) {
      final now       = DateTime.now();
      DateTime start;
      switch (filter) {
        case 'today':
          start = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          start = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(start.year, start.month, start.day);
          break;
        case 'month':
          start = DateTime(now.year, now.month, 1);
          break;
        default:
          start = DateTime(1970);
      }
      if (filter != 'all') {
        whereClause = 'createdAt >= ?';
        whereArgs   = [start.toIso8601String()];
      }
    }
    final sales = await db.query(
      'sales',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );
    final results = <Map<String, dynamic>>[];
    for (final sale in sales) {
      final items = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [sale['id']],
      );
      results.add({'sale': sale, 'items': items});
    }
    return results;
  }

  Future<Map<String, dynamic>?> getSale(String id) async {
    final db = await database;
    final r = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? r.first : null;
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
    await db.delete('sale_items', where: 'saleId = ?', whereArgs: [id]);
    await db.delete('sales',       where: 'id = ?',       whereArgs: [id]);
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

  // ════════════════════════════════════════════════════════════════════════
  // GENERIC SYNC HELPERS  (used by SyncService AND by local CRUD mutations)
  // ════════════════════════════════════════════════════════════════════════

  /// Inserts or replaces a row in [table] from [jsonData] (camelCase keys),
  /// then pushes a matching `action='insert'` row into `sync_queue`.
  ///
  /// Works for any of the four business tables:
  /// `categories`, `inventory`, `sales`, `sale_items`.
  Future<int> insertOrUpdate(
      String table, Map<String, dynamic> jsonData) async {
    final db = await database;
    await db.insert(
      table,
      jsonData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return await _enqueue(table, 'insert', jsonData);
  }

  /// Deletes a row by [id] from [table] and pushes an `action='delete'`
  /// entry into `sync_queue`.
  ///
  /// Sends only `{'id': id}` as the JSON payload to minimise bandwidth.
  Future<int> deleteRecord(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    return await _enqueue(table, 'delete', {'id': id});
  }

  /// Internal helper — writes one row into `sync_queue`.
  Future<int> _enqueue(
      String table, String action, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'table_name': table,
      'action':     action,
      'data_json':  jsonEncode(data),
      'status':     'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Returns all rows from `sync_queue` whose `status` is `'pending'`,
  /// ordered oldest-first.
  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where:             'status = ?',
      whereArgs:         ['pending'],
      orderBy:           'id ASC',
    );
  }

  /// Marks the queue rows identified by [ids] as `'sent'`.
  Future<void> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db  = await database;
    final inClause = ids.map((_) => '?').join(',');
    await db.update(
      'sync_queue',
      {'status': 'sent'},
      where:     'id IN ($inClause)',
      whereArgs: ids,
    );
  }

  /// Deletes rows from `sync_queue` with status `'sent'` that are older
  /// than [olderThanDays] days.
  Future<void> pruneSentQueue({int olderThanDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .toIso8601String();
    await db.delete(
      'sync_queue',
      where:     'status = ? AND created_at < ?',
      whereArgs: ['sent', cutoff],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // LAST-SYNC TIMESTAMP HELPERS  (SharedPreferences)
  // ════════════════════════════════════════════════════════════════════════

  Future<String?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastSyncKey);
  }

  Future<void> setLastSyncedAt(String iso8601) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastSyncKey, iso8601);
  }
}
