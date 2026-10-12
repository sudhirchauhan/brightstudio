CREATE TABLE bright_workspace_receipts (
 owner_id uuid NOT NULL REFERENCES bright_users(id),
 idempotency_key text NOT NULL,
 request_hash bytea NOT NULL,
 response_json text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(owner_id,idempotency_key)
);
