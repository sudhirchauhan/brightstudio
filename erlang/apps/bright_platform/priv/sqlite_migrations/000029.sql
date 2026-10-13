CREATE TABLE bright_mutation_receipts (
 owner_id TEXT NOT NULL REFERENCES bright_users(id), feature text NOT NULL,
 idempotency_key text NOT NULL, request_hash BLOB NOT NULL, response_json text NOT NULL,
 PRIMARY KEY(owner_id,feature,idempotency_key)
);
