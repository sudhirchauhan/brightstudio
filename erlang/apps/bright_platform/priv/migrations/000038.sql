CREATE TABLE bright_password_resets (
 id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
 token_hash bytea NOT NULL UNIQUE CHECK(octet_length(token_hash)=32),
 password_hash bytea NOT NULL,
 expires_at_ms bigint NOT NULL, consumed_at_ms bigint,
 created_at_ms bigint NOT NULL
);
