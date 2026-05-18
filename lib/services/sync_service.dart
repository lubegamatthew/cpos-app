import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../db_helper.dart' show DatabaseHelper;

/// Base URL for the remote sync endpoint.
const _baseUrl = 'https://chillonpos.is-great.net';

/// Syncs data between local SQLite and the remote server.
///
/// 1. **Push** – sends all `pending` `sync_queue` rows to the server.
/// 2. **Pull** – fetches records changed since `last_sync_timestamp`.
class SyncService {
  /// Full push + pull cycle.
  static Future<bool> sync({
    void Function(String message)? onStatus,
  }) async {
    await _pushLocalQueue(onStatus: onStatus);
    final changed = await _pullRemoteChanges(onStatus: onStatus);
    return changed;
  }

  // ── PUSH ────────────────────────────────────────────────────────────────

  static Future<void> _pushLocalQueue({
    void Function(String message)? onStatus,
  }) async {
    final pending = await DatabaseHelper.instance.getPendingQueue();
    if (pending.isEmpty) {
      onStatus?.call('No local changes to push.');
      return;
    }

    onStatus?.call('Pushing ${pending.length} pending change(s)…');

    var idsToMark = <int>[];
    var failures = <String>[];

    for (final row in pending) {
      final qid = row['id'] as int;
      try {
        final body = {
          'queue_id':   qid,
          'table_name': row['table_name'],
          'action':     row['action'],
          'data_json':  row['data_json'],
          'created_at': row['created_at'],
        };

        final resp = await post(
          Uri.parse('$_baseUrl/api/sync.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          idsToMark.add(qid);
        } else {
          failures.add('queue row $qid -> HTTP ${resp.statusCode}');
        }
      } catch (e) {
        failures.add('queue row $qid -> $e');
      }
    }

    if (idsToMark.isNotEmpty) {
      await DatabaseHelper.instance.markAsSynced(idsToMark);
      await DatabaseHelper.instance.pruneSentQueue(olderThanDays: 30);
      onStatus?.call('Pushed ${idsToMark.length} change(s) successfully.');
    }

    if (failures.isNotEmpty) {
      if (kDebugMode) {
        for (final f in failures) debugPrint('Sync push failure: $f');
      }
      onStatus?.call(
        '${failures.length} change(s) could not be pushed — will retry.',
      );
    }
  }

  // ── PULL ────────────────────────────────────────────────────────────────

  static Future<bool> _pullRemoteChanges({
    void Function(String message)? onStatus,
  }) async {
    final since = await DatabaseHelper.instance.getLastSyncedAt();
    onStatus?.call(
      since == null
          ? 'No previous sync — performing full pull…'
          : 'Pulling changes since $since…',
    );

    try {
      final uri = since != null
          ? Uri.parse('$_baseUrl/api/sync.php').replace(
              queryParameters: <String, String>{'since': since},
            )
          : Uri.parse('$_baseUrl/api/sync.php');

      final resp = await get(uri).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        onStatus?.call('Server error ${resp.statusCode} during pull.');
        return false;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return await _applyRemotePayload(data, onStatus: onStatus);
    } catch (e) {
      if (kDebugMode) debugPrint('Sync pull error: $e');
      onStatus?.call('Pull failed: $e');
      return false;
    }
  }

  static Future<bool> _applyRemotePayload(
    Map<String, dynamic> data, {
    void Function(String message)? onStatus,
  }) async {
    var totalChanged = 0;
    final byTable = <String, int>{};

    for (final entry in data.entries) {
      if (entry.key == 'synced_at') continue;
      final list = (entry.value as List?)?.cast<Map<String, dynamic>>();
      if (list == null || list.isEmpty) continue;

      int newCount = 0, updCount = 0;

      switch (entry.key) {
        case 'inventory':
          (newCount, updCount) = await _upsertInventory(list);
          break;
        case 'categories':
          (newCount, updCount) = await _upsertCategories(list);
          break;
        case 'sales':
          (newCount, updCount) = await _upsertSales(list);
          break;
        case 'sale_items':
          (newCount, updCount) = await _upsertSaleItems(list);
          break;
        default:
          continue;
      }

      final sum = newCount + updCount;
      if (sum > 0) byTable[entry.key] = sum;
      totalChanged += sum;
    }

    final syncedAt = data['synced_at'] as String?;
    if (syncedAt != null) {
      await DatabaseHelper.instance.setLastSyncedAt(syncedAt);
    }

    if (totalChanged > 0) {
      final parts = <String>[];
      byTable.forEach((t, c) => parts.add('$t: $c'));
      onStatus?.call(
        'Synced $totalChanged record(s) from server (${parts.join(', ')})',
      );
    } else {
      onStatus?.call("You're already fully synced.");
    }
    return totalChanged > 0;
  }

  // ── PER-TABLE UPSERTS ────────────────────────────────────────────────────

  static Future<(int, int)> _upsertInventory(
    List<Map<String, dynamic>> rows,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final ids = rows.map((r) => r['id'] as String).toList();
    final localIds = <String>{};

    if (ids.isNotEmpty) {
      final ph = ids.map((_) => '?').join(',');
      final hits = await db.query(
        'inventory',
        where: 'id IN ($ph)',
        whereArgs: ids,
      );
      for (final r in hits) localIds.add(r['id'] as String);
    }

    var inserted = 0;
    var updated = 0;
    final batch = db.batch();
    final nowStamp = DateTime.now().toIso8601String();

    for (final row in rows) {
      final id = row['id'] as String;
      final payload = <String, dynamic>{
        'id': id,
        'name': row['name'] as String,
        'category': row['category'] as String,
        'quantity': (row['quantity'] as num?)?.toInt() ?? 0,
        'buyPrice': (row['buyPrice'] as num?)?.toDouble() ?? 0.0,
        'sellPrice': (row['sellPrice'] as num?)?.toDouble() ?? 0.0,
        'unit': row['unit'] as String? ?? 'pcs',
        'description': row['description'] as String? ?? '',
        'createdAt': row['createdAt'] as String? ?? nowStamp,
      };

      if (localIds.contains(id)) {
        payload['updatedAt'] = nowStamp;
        updated++;
      } else {
        inserted++;
      }

      batch.insert(
        'inventory',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    return (inserted, updated);
  }

  static Future<(int, int)> _upsertCategories(
    List<Map<String, dynamic>> rows,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final ids = rows.map((r) => r['id'] as String).toList();
    final localIds = <String>{};

    if (ids.isNotEmpty) {
      final ph = ids.map((_) => '?').join(',');
      final hits = await db.query(
        'categories',
        where: 'id IN ($ph)',
        whereArgs: ids,
      );
      for (final r in hits) localIds.add(r['id'] as String);
    }

    var inserted = 0;
    var updated = 0;
    final batch = db.batch();
    final nowStamp = DateTime.now().toIso8601String();

    for (final row in rows) {
      final id = row['id'] as String;
      final payload = <String, dynamic>{
        'id': id,
        'name': row['name'] as String,
        'description': row['description'] as String? ?? '',
        'createdAt': row['createdAt'] as String? ?? nowStamp,
      };

      if (localIds.contains(id)) {
        updated++;
      } else {
        inserted++;
      }

      batch.insert(
        'categories',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    return (inserted, updated);
  }

  static Future<(int, int)> _upsertSales(
    List<Map<String, dynamic>> rows,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final ids = rows.map((r) => r['id'] as String).toList();
    final localIds = <String>{};

    if (ids.isNotEmpty) {
      final ph = ids.map((_) => '?').join(',');
      final hits = await db.query(
        'sales',
        where: 'id IN ($ph)',
        whereArgs: ids,
      );
      for (final r in hits) localIds.add(r['id'] as String);
    }

    var inserted = 0;
    var updated = 0;
    final batch = db.batch();
    final nowStamp = DateTime.now().toIso8601String();

    for (final row in rows) {
      final id = row['id'] as String;
      final payload = <String, dynamic>{
        'id': id,
        'customerName': row['customerName'] as String? ?? 'Walk-in Customer',
        'customerPhone': row['customerPhone'] as String? ?? '',
        'totalAmount': (row['totalAmount'] as num?)?.toDouble() ?? 0.0,
        'totalProfit': (row['totalProfit'] as num?)?.toDouble() ?? 0.0,
        'paymentMethod': row['paymentMethod'] as String? ?? 'Cash',
        'status': row['status'] as String? ?? 'Completed',
        'notes': row['notes'] as String? ?? '',
        'createdAt': row['createdAt'] as String? ?? nowStamp,
      };

      if (localIds.contains(id)) {
        updated++;
      } else {
        inserted++;
      }

      batch.insert(
        'sales',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    return (inserted, updated);
  }

  static Future<(int, int)> _upsertSaleItems(
    List<Map<String, dynamic>> rows,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final ids = rows.map((r) => r['id'] as String).toList();
    final localIds = <String>{};

    if (ids.isNotEmpty) {
      final ph = ids.map((_) => '?').join(',');
      final hits = await db.query(
        'sale_items',
        where: 'id IN ($ph)',
        whereArgs: ids,
      );
      for (final r in hits) localIds.add(r['id'] as String);
    }

    var inserted = 0;
    var updated = 0;
    final batch = db.batch();
    final nowStamp = DateTime.now().toIso8601String();

    for (final row in rows) {
      final id = row['id'] as String;
      final payload = <String, dynamic>{
        'id': id,
        'saleId': row['saleId'] as String,
        'inventoryId': row['inventoryId'] as String,
        'itemName': row['itemName'] as String,
        'quantity': (row['quantity'] as num?)?.toInt() ?? 0,
        'buyPrice': (row['buyPrice'] as num?)?.toDouble() ?? 0.0,
        'sellPrice': row['sellPrice'] as num?,
        'totalCost': (row['totalCost'] as num?)?.toDouble() ?? 0.0,
        'totalRevenue': (row['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        'profit': (row['profit'] as num?)?.toDouble() ?? 0.0,
        'createdAt': row['createdAt'] as String? ?? nowStamp,
      };

      if (localIds.contains(id)) {
        updated++;
      } else {
        inserted++;
      }

      batch.insert(
        'sale_items',
        payload,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    return (inserted, updated);
  }
}
