CREATE TABLE bright_credentials (
 user_id uuid PRIMARY KEY REFERENCES bright_users(id) ON DELETE CASCADE,
 salt bytea NOT NULL CHECK (octet_length(salt) = 16),
 password_hash bytea NOT NULL CHECK (octet_length(password_hash) = 32)
);
