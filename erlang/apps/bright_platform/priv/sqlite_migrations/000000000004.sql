CREATE TABLE IF NOT EXISTS bright_sessions (
  token_hash BLOB NOT NULL PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  revoked_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
  CONSTRAINT bright_sessions_token_hash_size CHECK (length(CAST(token_hash AS BLOB)) = 32)
);