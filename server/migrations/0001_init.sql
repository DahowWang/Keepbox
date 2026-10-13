-- 每筆資料（檔案／資料夾／標籤）一列；seq 是全域遞增的異動序號，客戶端用它拉增量。
CREATE TABLE records (
  type TEXT NOT NULL CHECK (type IN ('file', 'folder', 'tag')),
  id TEXT NOT NULL,
  data TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  seq INTEGER NOT NULL,
  PRIMARY KEY (type, id)
);
CREATE INDEX idx_records_seq ON records (seq);
