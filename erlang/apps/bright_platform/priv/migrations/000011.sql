CREATE TABLE bright_evidence (
 id uuid PRIMARY KEY,
 owner_id uuid NOT NULL REFERENCES bright_users(id),
 source_id uuid NOT NULL,
 revision_id uuid NOT NULL,
 start_byte integer NOT NULL CHECK(start_byte>=0),
 end_byte integer NOT NULL CHECK(end_byte>start_byte),
 quote text NOT NULL CHECK(octet_length(quote) BETWEEN 1 AND 8192),
 text_sha256 bytea NOT NULL CHECK(octet_length(text_sha256)=32),
 note text NOT NULL CHECK(length(note)<=4000),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 idempotency_key text NOT NULL CHECK(length(idempotency_key) BETWEEN 16 AND 128),
 request_hash bytea NOT NULL CHECK(octet_length(request_hash)=32),
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(revision_id,source_id,owner_id) REFERENCES bright_source_revisions(id,source_id,owner_id),
 UNIQUE(id,owner_id), UNIQUE(owner_id,idempotency_key)
);
