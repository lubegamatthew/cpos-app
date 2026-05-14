-- POS Database Schema
-- Database: cpos.db (SQLite)
-- Version: 2

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
-- Table: orders
-- ============================================
CREATE TABLE orders (
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
-- Table: order_items
-- ============================================
CREATE TABLE order_items (
  id           TEXT PRIMARY KEY,
  orderId      TEXT NOT NULL,
  inventoryId  TEXT NOT NULL,
  itemName     TEXT NOT NULL,
  quantity     INTEGER NOT NULL,
  buyPrice     REAL NOT NULL,
  sellPrice    REAL NOT NULL,
  totalCost    REAL NOT NULL,
  totalRevenue REAL NOT NULL,
  profit       REAL NOT NULL,
  FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE,
  FOREIGN KEY (inventoryId) REFERENCES inventory (id)
);