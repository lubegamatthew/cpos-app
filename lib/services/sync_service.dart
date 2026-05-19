import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../db_helper.dart' show DatabaseHelper;

/// Base URL for the remote sync endpoint.
const _baseUrl = 'https://chillonpos.is-great.net';

/// Low-level HTTPS client that accepts any server certificate.
///
/// This is necessary because InfinityFree's HTTPS presentation chain does not
/// validate cleanly from the device.  Only `SyncService` uses this factory so
/// the bypass is scoped to a single logical surface.

/// Response type for sync HTTP calls.
typedef _SyncResp = ({int statusCode, String body});

/// Syncs data between local SQLite and the remote server.
///
/// 1. **Push** – sends all `pending` `sync_queue` rows to the server.
/// 2. **Pull** – fetches records changed since `last_sync_timestamp`.
  class SyncService {
  // ── Uri constants ────────────────────────────────────────────────────────

  static final Uri _syncUri = Uri.parse('$_baseUrl/api/sync.php');

  /// Full push + pull cycle.
  static Future<bool> sync({
      void Function(String message)? onStatus,
  }) async {
      _reconciledThisRound = false; // allow reconciliation this round
      await pushLocalQueue(onStatus: onStatus);
      _reconciledThisRound = true; // prevent double-enqueue this tap
      final changed = await pullRemoteChanges(onStatus: onStatus);
      return changed;
  }

  // ── PUSH ────────────────────────────────────────────────────────────────

  static Future<void> pushLocalQueue({
      void Function(String message)? onStatus,
  }) async {
      // Reconcile: enqueue any local rows not yet tracked by sync_queue.
      // Catches seed data, `insertAllInventoryItems()` rows and every other
      // path that writes directly to SQLite.
      await _reconcileDirtyRows(onStatus: onStatus);

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
        final tbl = row['table_name'] as String? ?? '?';
        final label = _tableLabel(tbl);
        onStatus?.call('Pushing $label…');

        try {
          final body = {
            'queue_id': qid,
            'table_name': row['table_name'],
            'action': row['action'],
            'data_json': row['data_json'],
            'created_at': row['created_at'],
          };
          final rawBody = jsonEncode(body);

          debugPrint('[Sync push] queue_id=$qid '
              'table=${row['table_name']} action=${row['action']} '
              'payload_len=${rawBody.length}');

          final resp = await _postToSync(body: rawBody).timeout(const Duration(seconds: 30));

          if (kDebugMode) {
            debugPrint('[Sync push] queue_id=$qid '
                'HTTP ${resp.statusCode} '
                'body="${resp.body}"');
          }

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            idsToMark.add(qid);
            onStatus?.call('  Pushed $label OK');
          } else {
            final err =
                'HTTP ${resp.statusCode}: ${resp.body.isNotEmpty ? resp.body : 'no body'}';
            failures.add('$label (queue row $qid)');
            onStatus?.call('  $label FAILED — $err');
          }
        } catch (e) {
          failures.add('$label (queue row $qid) -> $e');
          onStatus?.call('  $label FAILED — $e');
        }
      }

      if (idsToMark.isNotEmpty) {
        await DatabaseHelper.instance.markAsSynced(idsToMark);
        await DatabaseHelper.instance.pruneSentQueue(olderThanDays: 30);
        onStatus?.call('${idsToMark.length} row(s) pushed to server.');
      }

      if (failures.isNotEmpty) {
        for (final f in failures) {
          debugPrint('Sync push failure: $f');
        }
        onStatus?.call(
          '${failures.length} push failure(s) — '
          '${failures.join(', ')} — will retry.',
        );
      } else if (idsToMark.isEmpty) {
        onStatus?.call('No local changes to push.');
      }
  }

  // ── PULL ────────────────────────────────────────────────────────────────

  static Future<bool> pullRemoteChanges({
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
            ? _syncUri.replace(
                queryParameters: <String, String>{'since': since},
              )
            : _syncUri;

        final resp = await _getFromSync(uri).timeout(const Duration(seconds: 30));

        debugPrint('[Sync pull] GET ${uri.path}?${uri.query} '
            'HTTP ${resp.statusCode} '
            'body="${resp.body}"');

        if (resp.statusCode != 200) {
          onStatus?.call('Server returned HTTP ${resp.statusCode} during pull.');
          return false;
        }

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (kDebugMode) {
          for (final k in data.keys) {
            final v = data[k];
            if (v is List) {
              debugPrint('[Sync pull] key=$k → List(${v.length} items)');
            } else {
              debugPrint('[Sync pull] key=$k → $v');
            }
          }
        }
        return await _applyRemotePayload(data, onStatus: onStatus);
      } catch (e) {
        if (kDebugMode) debugPrint('Sync pull error: $e');
        onStatus?.call('Pull failed: $e');
        return false;
      }
  }

  /// Helper: reads an [HttpClientResponse] into a [_SyncResp].
  static Future<_SyncResp> _readResp(HttpClientResponse res) async {
    final bytes = await res.fold(
      <int>[],
      (list, chunk) => list..addAll(chunk),
    );
    return (statusCode: res.statusCode, body: utf8.decode(bytes));
  }

  /// Low-level POST; cert bypass scoped to a single factory.
  static Future<_SyncResp> _postToSync({
    required String body,
  }) async {
    final io = HttpClient()
      ..badCertificateCallback = (p, h, c) => true;
    try {
      final req = await io.postUrl(_syncUri);
      req.headers.set('Content-Type', 'application/json');
      req.write(body);
      return await _readResp(await req.close());
    } finally {
      io.close();
    }
  }

  /// Low-level GET; cert bypass scoped to a single factory.
  static Future<_SyncResp> _getFromSync(Uri uri) async {
    final io = HttpClient()
      ..badCertificateCallback = (p, h, c) => true;
    try {
      final req = await io.getUrl(uri);
      return await _readResp(await req.close());
    } finally {
      io.close();
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

        int newCount = 0;
        int updCount = 0;
        final table = entry.key;

        onStatus?.call('Pulling ${_tableLabel(table)} (${list.length})…');

        switch (table) {
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
        if (sum > 0) {
          byTable[table] = sum;
          onStatus?.call(
            '  ${_tableLabel(table)}: +$newCount new, $updCount updated',
          );
        } else {
          onStatus?.call('  ${_tableLabel(table)}: no changes');
        }
        totalChanged += sum;
      }

      final syncedAt = data['synced_at'] as String?;
      if (syncedAt != null) {
        await DatabaseHelper.instance.setLastSyncedAt(syncedAt);
      }

      if (totalChanged > 0) {
        final parts = <String>[];
        for (final entry in byTable.entries) {
          parts.add('${_tableLabel(entry.key)}: +${entry.value}');
        }
        onStatus?.call(
          'Pull: $totalChanged record(s) applied (${parts.join(', ')}).',
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
        for (final r in hits) {
          localIds.add(r['id'] as String);
        }
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
          'categoryId': row['categoryId'] as String? ?? '',
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
        for (final r in hits) {
          localIds.add(r['id'] as String);
        }
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
        for (final r in hits) {
          localIds.add(r['id'] as String);
        }
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
        for (final r in hits) {
          localIds.add(r['id'] as String);
        }
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

      // ── LOCAL → SYNC QUEUE RECONCILIATION ────────────────────────────────

      /// Scans each core table for rows whose `id` is not yet present in
      /// `sync_queue` (for that table) and enqueues them.
      ///
      /// Catches: seed data, `insertAllInventoryItems()` rows, POS-sale rows,
      /// and any other path that writes directly to SQLite.
      ///
      /// Runs at most once per `sync()` call.
  static bool _reconciledThisRound = false;

      /// Returns a human-readable label for a DB table name.
  static String _tableLabel(String table) {
      switch (table) {
        case 'inventory':
          return 'Inventory';
        case 'categories':
          return 'Categories';
        case 'sales':
          return 'Sales';
        case 'sale_items':
          return 'Sale Items';
        case 'sync_queue':
          return 'Sync Queue';
        default:
          return table[0].toUpperCase() + table.substring(1);
      }
  }

  static Future<void> _reconcileDirtyRows({
      void Function(String message)? onStatus,
  }) async {
      if (_reconciledThisRound) {
        return;
      }

        // Per-table column lists MUST match the physical DB column names.
      const tables = [
        (
          'inventory',
          ['id', 'name', 'categoryId', 'quantity', 'buyPrice',
            'sellPrice', 'unit', 'description', 'createdAt'],
        ),
        ('categories', ['id', 'name', 'description', 'createdAt']),
        (
          'sales',
          [
            'id',
            'customerName',
            'customerPhone',
            'totalAmount',
            'totalProfit',
            'paymentMethod',
            'status',
            'notes',
            'createdAt',
          ],
        ),
        (
          'sale_items',
          [
            'id',
            'saleId',
            'inventoryId',
            'itemName',
            'quantity',
            'buyPrice',
            'sellPrice',
            'totalCost',
            'totalRevenue',
            'profit',
            'createdAt',
          ],
        ),
      ];

      int enqueued = 0;
      final db = await DatabaseHelper.instance.database;

      for (final (String table, List<String> columns) in tables) {
          // Step 1 – collect ids already tracked for this table.
        final tracked = <String>{};
        {
          final rows = await db.query(
            'sync_queue',
            columns: ['data_json'],
            where: 'table_name = ?',
            whereArgs: [table],
          );
          for (final r in rows) {
            final str = r['data_json'] as String?;
            if (str != null) {
                // Every data_json map we write contains "id":"<val>".
              final m = RegExp(r'"id"\s*:\s*"([^"]+)"').firstMatch(str);
              if (m != null) {
                tracked.add(m.group(1)!);
              }
            }
          }
        }

          // Step 2 – read every row in this table.
        final rows = await db.query(table);
        if (rows.isEmpty) {
          continue;
        }

          // Step 3 – batch-insert untracked rows into sync_queue.
        final batchIn = db.batch();
        for (final row in rows) {
          final rowId = row['id'] as String?;
          if (rowId == null || tracked.contains(rowId)) {
            continue;
          }

          final payload = <String, dynamic>{};
          for (final col in columns) {
            final v = row[col];
            if (v is num) {
              payload[col] = v.toDouble();
            } else if (v is int) {
              payload[col] = v.toDouble();
            } else if (v is bool) {
              payload[col] = v;
            } else if (v != null) {
              payload[col] = v.toString();
            }
          }

          batchIn.insert(
            'sync_queue',
            {
              'table_name': table,
              'action': 'insert',
              'data_json': jsonEncode(payload),
              'status': 'pending',
              'created_at': DateTime.now().toIso8601String(),
            },
          );
          enqueued++;
        }

        if (enqueued > 0) {
          await batchIn.commit(noResult: true);
        }
      }

      if (enqueued > 0 && onStatus != null) {
        onStatus(
          'Found $enqueued local record(s) not yet on the server — '
          'will push now.',
        );
      }
  }
}
