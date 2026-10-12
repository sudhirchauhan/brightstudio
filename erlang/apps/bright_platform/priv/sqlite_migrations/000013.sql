CREATE TABLE bright_evidence_notes (
 evidence_id TEXT NOT NULL,
 owner_id TEXT NOT NULL,
 version integer NOT NULL CHECK(version>0),
 note text NOT NULL CHECK(length(note)<=4000),
 idempotency_key text NOT NULL,
 request_hash BLOB NOT NULL,
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 PRIMARY KEY(evidence_id,version),
 UNIQUE(owner_id,idempotency_key),
 FOREIGN KEY(evidence_id,owner_id) REFERENCES bright_evidence(id,owner_id)
);
