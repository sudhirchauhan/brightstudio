CREATE TABLE bright_projects (
 id TEXT NOT NULL PRIMARY KEY,
 owner_id TEXT NOT NULL REFERENCES bright_users(id),
 title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 200),
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 UNIQUE(id, owner_id)
);
