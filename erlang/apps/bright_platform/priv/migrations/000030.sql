CREATE TABLE bright_documents (
 id uuid PRIMARY KEY, owner_id uuid NOT NULL, project_id uuid NOT NULL,
 title text NOT NULL, version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(id,owner_id),
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id)
);
