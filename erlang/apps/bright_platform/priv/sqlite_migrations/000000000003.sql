CREATE TABLE IF NOT EXISTS bright_memberships (
  user_id TEXT NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
  workspace_id TEXT NOT NULL,
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'editor', 'viewer')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
  PRIMARY KEY (user_id, workspace_id)
);