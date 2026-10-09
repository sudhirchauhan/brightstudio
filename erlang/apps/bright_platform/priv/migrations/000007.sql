CREATE TABLE bright_sources (
 id uuid PRIMARY KEY,
 owner_id uuid NOT NULL REFERENCES bright_users(id),
 project_id uuid NOT NULL,
 title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 200),
 url text NOT NULL DEFAULT '' CHECK (length(url) <= 2048),
 kind text NOT NULL CHECK (kind IN ('link', 'book', 'article', 'note')),
 idempotency_key text NOT NULL CHECK (length(idempotency_key) BETWEEN 16 AND 128),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(project_id, owner_id) REFERENCES bright_projects(id, owner_id),
 UNIQUE(owner_id, idempotency_key)
);
