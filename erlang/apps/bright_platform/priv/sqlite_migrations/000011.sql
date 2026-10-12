CREATE TABLE bright_evidence (
 id TEXT NOT NULL PRIMARY KEY,
 owner_id TEXT NOT NULL REFERENCES bright_users(id),
 source_id TEXT NOT NULL,
 revision_id TEXT NOT NULL,
 start_byte integer NOT NULL CHECK(start_byte>=0),
 end_byte integer NOT NULL CHECK(end_byte>start_byte),
 quote text NOT NULL CHECK(length(CAST(quote AS BLOB)) BETWEEN 1 AND 8192),
 text_sha256 BLOB NOT NULL CHECK(length(CAST(text_sha256 AS BLOB))=32),
 note text NOT NULL CHECK(length(note)<=4000),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 16 AND 128),
 request_hash BLOB NOT NULL CHECK(length(CAST(request_hash AS BLOB))=32),
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 FOREIGN KEY(revision_id,source_id,owner_id) REFERENCES bright_source_revisions(id,source_id,owner_id),
 UNIQUE(id,owner_id), UNIQUE(owner_id,idempotency_key)
);
