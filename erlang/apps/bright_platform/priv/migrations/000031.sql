CREATE TABLE bright_document_versions (
 document_id uuid NOT NULL, owner_id uuid NOT NULL, version integer NOT NULL CHECK(version>0),
 snapshot_json text NOT NULL, created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(document_id,version),
 FOREIGN KEY(document_id,owner_id) REFERENCES bright_documents(id,owner_id)
);
