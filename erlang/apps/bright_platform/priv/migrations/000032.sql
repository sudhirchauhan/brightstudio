CREATE TABLE bright_ai_attempts (
 id uuid PRIMARY KEY, owner_id uuid NOT NULL, project_id uuid NOT NULL,
 mode text NOT NULL CHECK(mode IN ('explain','compare','feedback')), engine text NOT NULL CHECK(engine IN ('evidence','generated')),
 state text NOT NULL CHECK(state IN ('queued','processing','ready','failed')), prompt text NOT NULL,
 citations_json text NOT NULL, result_json text NOT NULL DEFAULT '{}', failure text NOT NULL DEFAULT '',
 lease_token uuid, lease_until_ms bigint, created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id)
);
