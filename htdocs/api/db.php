<?php
// htdocs/api/db.php
// InfinityFree MySQL connection + idempotent table creation.

// ── Real InfinityFree credentials ───────────────────────────────────────────
$host     = 'sql101.infinityfree.com';
$dbname   = 'if0_40026929_chillion_pos';
$username = 'if0_40026929';
$password = 'ZZOOvWHt0JCKl';
// ─────────────────────────────────────────────────────────────────────────────

try {
    $dsn = "mysql:host=$host;dbname=$dbname;charset=utf8mb4";
    $pdo = new PDO($dsn, $username, $password,
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
} catch (PDOException $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['status' => 'error',
        'message' => 'DB connection failed: ' . $e->getMessage()]);
    exit;
}

// ── Idempotent table creation ────────────────────────────────────────────────

$pdo->exec("
    CREATE TABLE IF NOT EXISTS categories (
      id          VARCHAR(64)   PRIMARY KEY,
      name        VARCHAR(255) NOT NULL UNIQUE,
      description TEXT          DEFAULT '',
      created_at  DATETIME      NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$pdo->exec("
    CREATE TABLE IF NOT EXISTS inventory (
      id          VARCHAR(64)   PRIMARY KEY,
      name        VARCHAR(255) NOT NULL,
      category_id VARCHAR(64)  NOT NULL,
      quantity    INT          NOT NULL DEFAULT 0,
      buy_price   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      sell_price  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      unit        VARCHAR(32)  DEFAULT 'pcs',
      description TEXT         DEFAULT '',
      created_at  DATETIME     NOT NULL,
      updated_at  DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      FOREIGN KEY (category_id) REFERENCES categories(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
      INDEX idx_category (category_id),
      INDEX idx_updated  (updated_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$pdo->exec("
    CREATE TABLE IF NOT EXISTS sales (
      id             VARCHAR(64)   PRIMARY KEY,
      customer_name  VARCHAR(255) DEFAULT 'Walk-in Customer',
      customer_phone VARCHAR(64)  DEFAULT '',
      total_amount   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      total_profit   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      payment_method VARCHAR(64)  DEFAULT 'Cash',
      status         VARCHAR(64)  DEFAULT 'Completed',
      notes          TEXT         DEFAULT '',
      created_at     DATETIME     NOT NULL,
      INDEX idx_status  (status),
      INDEX idx_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$pdo->exec("
    CREATE TABLE IF NOT EXISTS sale_items (
      id           VARCHAR(64)   PRIMARY KEY,
      sale_id      VARCHAR(64)  NOT NULL,
      inventory_id VARCHAR(64)  NOT NULL,
      item_name    VARCHAR(255) NOT NULL,
      quantity     INT          NOT NULL DEFAULT 0,
      buy_price    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      sell_price   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      total_cost   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      total_revenue DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      profit       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
      created_at   DATETIME     NOT NULL,
      FOREIGN KEY (sale_id)      REFERENCES sales(id)
        ON DELETE CASCADE    ON UPDATE CASCADE,
      FOREIGN KEY (inventory_id) REFERENCES inventory(id)
        ON DELETE RESTRICT   ON UPDATE CASCADE,
      INDEX idx_sale      (sale_id),
      INDEX idx_inventory (inventory_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");

$pdo->exec("
    CREATE TABLE IF NOT EXISTS sync_queue (
      id         INT          AUTO_INCREMENT PRIMARY KEY,
      table_name VARCHAR(64)  NOT NULL,
      action     VARCHAR(16)  NOT NULL,
      data_json  TEXT         NOT NULL,
      status     VARCHAR(16)  NOT NULL DEFAULT 'pending',
      created_at DATETIME     NOT NULL,
      INDEX idx_status (status)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
");
