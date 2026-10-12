CREATE TABLE bright_study_attempts (
 pass_id TEXT NOT NULL,
 owner_id TEXT NOT NULL,
 idempotency_key text NOT NULL,
 request_hash BLOB NOT NULL,
 step integer NOT NULL,
 answer text NOT NULL,
 correct boolean NOT NULL,
 response_json text NOT NULL,
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 FOREIGN KEY(pass_id,owner_id) REFERENCES bright_study_passes(id,owner_id),
 PRIMARY KEY(owner_id,idempotency_key)
);
