CREATE TABLE bright_evidence_boards (
 id TEXT NOT NULL PRIMARY KEY,
 owner_id TEXT NOT NULL,
 project_id TEXT NOT NULL,
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
 idempotency_key text NOT NULL,
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id),
 UNIQUE(id,owner_id), UNIQUE(owner_id,idempotency_key)
);
