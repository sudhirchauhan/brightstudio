CREATE TABLE bright_projects (
 id uuid PRIMARY KEY,
 owner_id uuid NOT NULL REFERENCES bright_users(id),
 title text NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 200),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(id, owner_id)
);
