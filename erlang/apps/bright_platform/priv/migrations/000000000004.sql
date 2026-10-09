CREATE TABLE IF NOT EXISTS bright_sessions (
  token_hash bytea PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bright_sessions_token_hash_size CHECK (octet_length(token_hash) = 32)
);