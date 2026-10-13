CREATE TABLE bright_password_resets (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
 token_hash BLOB NOT NULL UNIQUE CHECK(length(token_hash)=32),
 password_hash BLOB NOT NULL,
 expires_at_ms bigint NOT NULL, consumed_at_ms bigint,
 created_at_ms bigint NOT NULL
);
