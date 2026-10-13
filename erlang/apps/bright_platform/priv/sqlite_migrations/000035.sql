CREATE TABLE bright_media_jobs (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, project_id TEXT NOT NULL,
 title text NOT NULL, filename text NOT NULL, mime text NOT NULL CHECK(mime IN ('image/png','image/jpeg','audio/wav','audio/webm')),
 original BLOB NOT NULL CHECK(length(original) BETWEEN 1 AND 4194304),
 state text NOT NULL DEFAULT 'queued' CHECK(state IN ('queued','processing','ready','failed')),
 version integer NOT NULL DEFAULT 1 CHECK(version>0), attempts integer NOT NULL DEFAULT 0 CHECK(attempts BETWEEN 0 AND 3),
 error_code text NOT NULL DEFAULT '', lease_token TEXT, lease_until_ms bigint,
 source_id TEXT, revision_id TEXT, created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id),
 FOREIGN KEY(revision_id,source_id,owner_id) REFERENCES bright_source_revisions(id,source_id,owner_id)
);
