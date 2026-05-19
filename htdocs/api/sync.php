<?php
// htdocs/api/sync.php
// Receives a single push payload from the Flutter app, upserts into MySQL,
// then returns all rows changed since $since (for the pull step).

// Re-enable errors in this script so any SQL crash is visible in the JSON
// response rather than being swallowed by InfinityFree's display_errors=0.
@ini_set('display_errors', '1');
@ini_set('log_errors', '1');
error_reporting(E_ALL);

header('Content-Type: application/json');
require __DIR__ . '/db.php';

$rawInput = file_get_contents('php://input');
$data     = json_decode($rawInput, true);

// ─────────────────────────────────────────────────────────────────────────────
// PUSH  (POST with a single object)
// ─────────────────────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!$data || !is_array($data)) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'No data provided']);
        exit;
    }

    $tableName = $data['table_name'] ?? null;
    $action    = $data['action']    ?? null;
    $content   = json_decode($data['data_json'], true);

    if (!$tableName || !$content || empty($content['id'])) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Missing fields']);
        exit;
    }

    try {
        $rows = 0;

        switch ($tableName) {
            case 'inventory':
                $rows = upsertInventory($pdo, $content);
                break;

            case 'categories':
                $rows = upsertCategories($pdo, $content);
                break;

            case 'sales':
                $rows = upsertSales($pdo, $content);
                break;

            case 'sale_items':
                $rows = upsertSaleItems($pdo, $content);
                break;

            case 'sync_queue':
                // We don't mirror the local queue on the server.
                http_response_code(200);
                echo json_encode(['status' => 'ok', 'synced' => 0]);
                exit;

            default:
                http_response_code(400);
                echo json_encode(['status' => 'error',
                    'message' => "Unknown table: $tableName"]);
                exit;
        }

        http_response_code(200);
        echo json_encode(['status' => 'ok', 'synced' => $rows]);
        exit;
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
        exit;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PULL  (GET with optional ?since=…)
// ─────────────────────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $since = $_GET['since'] ?? null;

    try {
        echo json_encode(buildPullPayload($pdo, $since));
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
    }
    exit;
}

http_response_code(405);
echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);

// ═══════════════════════════════════════════════════════════════════════════════
// PER-TABLE UPSERT HELPERS
// Each returns the number of rows affected.
// ═══════════════════════════════════════════════════════════════════════════════

function upsertInventory(PDO $pdo, array $c): int {
    $stmt = $pdo->prepare(
        "INSERT INTO inventory
            (id, name, category_id, quantity, buy_price, sell_price,
             unit, description, created_at, updated_at)
         VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
            name        = VALUES(name),
            category_id = VALUES(category_id),
            quantity    = VALUES(quantity),
            buy_price   = VALUES(buy_price),
            sell_price  = VALUES(sell_price),
            unit        = VALUES(unit),
            description = VALUES(description),
            updated_at  = VALUES(updated_at)"
    );
    $stmt->execute([
        $c['id']          ?? '',
        $c['name']        ?? '',
        $c['categoryId']  ?? $c['category_id']  ?? null,
        $c['quantity']    ?? 0,
        $c['buyPrice']    ?? $c['buy_price']    ?? 0.00,
        $c['sellPrice']   ?? $c['sell_price']   ?? 0.00,
        $c['unit']        ?? $c['unit']         ?? 'pcs',
        $c['description'] ?? $c['description']  ?? '',
        $c['createdAt']   ?? $c['created_at']   ?? date('Y-m-d H:i:s'),
        date('Y-m-d H:i:s'),
    ]);
    return $stmt->rowCount();
}

function upsertCategories(PDO $pdo, array $c): int {
    $stmt = $pdo->prepare(
        "INSERT INTO categories (id, name, description, created_at)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
            name        = VALUES(name),
            description = VALUES(description)"
    );
    $stmt->execute([
        $c['id']          ?? '',
        $c['name']        ?? '',
        $c['description'] ?? '',
        $c['createdAt']   ?? date('Y-m-d H:i:s'),
    ]);
    return $stmt->rowCount();
}

function upsertSales(PDO $pdo, array $c): int {
    $stmt = $pdo->prepare(
        "INSERT INTO sales
            (id, customer_name, customer_phone, total_amount, total_profit,
             payment_method, status, notes, created_at)
         VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
            customer_name  = VALUES(customer_name),
            customer_phone = VALUES(customer_phone),
            total_amount   = VALUES(total_amount),
            total_profit   = VALUES(total_profit),
            payment_method = VALUES(payment_method),
            status         = VALUES(status),
            notes          = VALUES(notes)"
    );
    $stmt->execute([
        $c['id']            ?? '',
        $c['customerName']  ?? 'Walk-in Customer',
        $c['customerPhone'] ?? '',
        $c['totalAmount']   ?? 0.00,
        $c['totalProfit']   ?? 0.00,
        $c['paymentMethod'] ?? 'Cash',
        $c['status']        ?? 'Completed',
        $c['notes']         ?? '',
        $c['createdAt']     ?? date('Y-m-d H:i:s'),
    ]);
    return $stmt->rowCount();
}

function upsertSaleItems(PDO $pdo, array $c): int {
    $stmt = $pdo->prepare(
        "INSERT INTO sale_items
            (id, sale_id, inventory_id, item_name, quantity,
             buy_price, sell_price, total_cost, total_revenue, profit, created_at)
         VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
            sale_id       = VALUES(sale_id),
            inventory_id  = VALUES(inventory_id),
            item_name     = VALUES(item_name),
            quantity      = VALUES(quantity),
            buy_price     = VALUES(buy_price),
            sell_price    = VALUES(sell_price),
            total_cost    = VALUES(total_cost),
            total_revenue = VALUES(total_revenue),
            profit        = VALUES(profit)"
    );
    $stmt->execute([
        $c['id']          ?? '',
        $c['saleId']      ?? '',
        $c['inventoryId'] ?? '',
        $c['itemName']    ?? '',
        $c['quantity']    ?? 0,
        $c['buyPrice']    ?? 0.00,
        $c['sellPrice']   ?? 0.00,
        $c['totalCost']   ?? 0.00,
        $c['totalRevenue']?? 0.00,
        $c['profit']      ?? 0.00,
        $c['createdAt']   ?? date('Y-m-d H:i:s'),
    ]);
    return $stmt->rowCount();
}

// ═══════════════════════════════════════════════════════════════════════════════
// PULL PAYLOAD BUILDER
// ═══════════════════════════════════════════════════════════════════════════════

function buildPullPayload(PDO $pdo, ?string $since): array {
    $payload = ['synced_at' => date('Y-m-d H:i:s')];

    $tables = [
        'inventory'  => ['id','name','category_id','quantity','buy_price','sell_price','unit','description','created_at','updated_at'],
        'categories' => ['id','name','description','created_at'],
        'sales'      => ['id','customer_name','customer_phone','total_amount','total_profit','payment_method','status','notes','created_at'],
        'sale_items' => ['id','sale_id','inventory_id','item_name','quantity','buy_price','sell_price','total_cost','total_revenue','profit','created_at'],
    ];

    foreach ($tables as $table => $cols) {
        if ($since) {
            $stmt = $pdo->prepare(
                "SELECT " . implode(',', $cols) . "
                 FROM $table
                 WHERE updated_at > ? OR created_at > ?"
            );
            $stmt->execute([$since, $since]);
        } else {
            $stmt = $pdo->query("SELECT " . implode(',', $cols) . " FROM $table");
        }

        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        if ($rows) $payload[$table] = $rows;
    }

    return $payload;
}
