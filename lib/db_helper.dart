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
      version: 1,
      onCreate: _createDB,
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
}