CREATE TABLE bright_workspaces (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
 title text NOT NULL, version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now'))
);
