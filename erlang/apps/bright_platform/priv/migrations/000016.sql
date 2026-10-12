CREATE TABLE bright_study_passes (
 id uuid PRIMARY KEY,
 owner_id uuid NOT NULL REFERENCES bright_users(id),
 source_id uuid NOT NULL,
 revision_id uuid NOT NULL,
 lessons_json text NOT NULL,
 text_sha256 bytea NOT NULL,
 step integer NOT NULL DEFAULT 0 CHECK(step BETWEEN 0 AND 6),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 state text NOT NULL DEFAULT 'active' CHECK(state IN ('active','summary','completed')),
 summary text NOT NULL DEFAULT '',
 idempotency_key text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(revision_id,source_id,owner_id) REFERENCES bright_source_revisions(id,source_id,owner_id),
 UNIQUE(id,owner_id), UNIQUE(owner_id,revision_id), UNIQUE(owner_id,idempotency_key)
);
