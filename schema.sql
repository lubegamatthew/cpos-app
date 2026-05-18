-- POS Database Schema
-- Database: cpos.db (SQLite)
-- Version: 5

-- ============================================
-- Table: categories
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  description TEXT DEFAULT '',
  createdAt   TEXT NOT NULL
);

-- ============================================
-- Table: inventory
-- ============================================
CREATE TABLE inventory (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  category    TEXT NOT NULL,
  quantity    INTEGER NOT NULL,
  buyPrice    REAL NOT NULL,
  sellPrice   REAL NOT NULL,
  unit        TEXT DEFAULT 'pcs',
  description TEXT DEFAULT '',
  createdAt   TEXT NOT NULL
);

-- ============================================
-- Table: sales
-- ============================================
CREATE TABLE sales (
  id             TEXT PRIMARY KEY,
  customerName   TEXT DEFAULT 'Walk-in Customer',
  customerPhone  TEXT DEFAULT '',
  totalAmount    REAL NOT NULL,
  totalProfit    REAL NOT NULL,
  paymentMethod  TEXT DEFAULT 'Cash',
  status         TEXT DEFAULT 'Completed',
  notes          TEXT DEFAULT '',
  createdAt      TEXT NOT NULL
);

-- ============================================
-- Table: sale_items
-- ============================================
CREATE TABLE sale_items (
  id           TEXT PRIMARY KEY,
  saleId       TEXT NOT NULL,
  inventoryId  TEXT NOT NULL,
  itemName     TEXT NOT NULL,
  quantity     INTEGER NOT NULL,
  buyPrice     REAL NOT NULL,
  sellPrice    REAL NOT NULL,
  totalCost    REAL NOT NULL,
  totalRevenue REAL NOT NULL,
  profit       REAL NOT NULL,
  FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE,
  FOREIGN KEY (inventoryId) REFERENCES inventory (id)
);

-- ============================================
-- Table: sync_queue
-- v5 — tracks local mutations waiting to be pushed to the server.
-- Rows stay `pending` until the sync round-trip succeeds, then
-- become `sent` and are pruned after 30 days.
-- ============================================
CREATE TABLE IF NOT EXISTS sync_queue (
    id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    action ENUM('insert', 'update', 'delete') NOT NULL,
    data_json JSON NOT NULL,
    status ENUM('pending', 'sent') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_status
  ON sync_queue (status);
