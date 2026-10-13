CREATE TABLE bright_document_versions (
 document_id TEXT NOT NULL, owner_id TEXT NOT NULL, version integer NOT NULL CHECK(version>0),
 snapshot_json text NOT NULL, created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 PRIMARY KEY(document_id,version),
 FOREIGN KEY(document_id,owner_id) REFERENCES bright_documents(id,owner_id)
);
