CREATE TABLE bright_credentials (
 user_id TEXT NOT NULL PRIMARY KEY REFERENCES bright_users(id) ON DELETE CASCADE,
 salt BLOB NOT NULL CHECK (length(CAST(salt AS BLOB)) = 16),
 password_hash BLOB NOT NULL CHECK (length(CAST(password_hash AS BLOB)) = 32)
);
