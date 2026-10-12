CREATE TABLE IF NOT EXISTS bright_users (
  id TEXT NOT NULL PRIMARY KEY,
  email text NOT NULL UNIQUE,
  display_name text NOT NULL DEFAULT '',
  disabled_at TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
  CONSTRAINT bright_users_email_not_empty CHECK (length(trim(email)) > 0)
);