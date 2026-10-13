CREATE TABLE bright_documents (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT NOT NULL,
 title text NOT NULL, version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')), UNIQUE(id,owner_id),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id)
);
