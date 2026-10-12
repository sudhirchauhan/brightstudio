CREATE TABLE bright_focus_receipts (
 owner_id TEXT NOT NULL REFERENCES bright_users(id),
 idempotency_key text NOT NULL,
 request_hash BLOB NOT NULL,
 response_json text NOT NULL,
 PRIMARY KEY(owner_id,idempotency_key)
);
