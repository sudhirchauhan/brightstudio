CREATE TABLE bright_ai_usage (
 owner_id TEXT NOT NULL REFERENCES bright_users(id), usage_day text NOT NULL,
 reserved_tokens integer NOT NULL CHECK(reserved_tokens>=0), PRIMARY KEY(owner_id,usage_day)
);
