CREATE TABLE bright_ai_attempts (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT NOT NULL,
 mode text NOT NULL CHECK(mode IN ('explain','compare','feedback')), engine text NOT NULL CHECK(engine IN ('evidence','generated')),
 state text NOT NULL CHECK(state IN ('queued','processing','ready','failed')), prompt text NOT NULL,
 citations_json text NOT NULL, result_json text NOT NULL DEFAULT '{}', failure text NOT NULL DEFAULT '',
 lease_token TEXT, lease_until_ms bigint, created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id)
);
