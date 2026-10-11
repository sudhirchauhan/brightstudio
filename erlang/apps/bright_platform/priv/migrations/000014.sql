CREATE TABLE bright_evidence_boards (
 id uuid PRIMARY KEY,
 owner_id uuid NOT NULL,
 project_id uuid NOT NULL,
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
 idempotency_key text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id),
 UNIQUE(id,owner_id), UNIQUE(owner_id,idempotency_key)
);
