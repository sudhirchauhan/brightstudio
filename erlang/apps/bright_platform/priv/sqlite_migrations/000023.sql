CREATE TABLE bright_workspace_receipts (
 owner_id TEXT NOT NULL REFERENCES bright_users(id),
 idempotency_key text NOT NULL,
 request_hash BLOB NOT NULL,
 response_json text NOT NULL,
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 PRIMARY KEY(owner_id,idempotency_key)
);
