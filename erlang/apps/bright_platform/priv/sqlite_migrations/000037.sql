CREATE TABLE bright_offline_packages (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT NOT NULL,
 payload_json text NOT NULL, expires_at_ms bigint NOT NULL, revoked integer NOT NULL DEFAULT 0 CHECK(revoked IN (0,1)), created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id)
);
