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