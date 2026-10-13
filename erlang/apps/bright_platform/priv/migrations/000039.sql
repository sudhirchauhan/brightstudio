CREATE TABLE bright_workspaces (
 id uuid PRIMARY KEY, owner_id uuid NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
 title text NOT NULL, version bigint NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now()
);
