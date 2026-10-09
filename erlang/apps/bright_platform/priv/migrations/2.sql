-- Native identity foundation. No legacy credential hashes are imported here.
CREATE TABLE IF NOT EXISTS bright_accounts (
    id uuid PRIMARY KEY,
    email text NOT NULL,
    password_hash text,
    password_scheme text,
    status text NOT NULL DEFAULT 'pending'
      CHECK (status IN ('pending','active','disabled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((password_hash IS NULL) = (password_scheme IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS bright_accounts_email_unique
    ON bright_accounts (lower(email));

CREATE TABLE IF NOT EXISTS bright_sessions (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES bright_accounts(id) ON DELETE CASCADE,
    token_digest bytea NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    CHECK (expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS bright_sessions_account_active
    ON bright_sessions(account_id, expires_at) WHERE revoked_at IS NULL;

CREATE TABLE IF NOT EXISTS bright_password_resets (
    id uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES bright_accounts(id) ON DELETE CASCADE,
    token_digest bytea NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    CHECK (expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS bright_identity_audit (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id uuid REFERENCES bright_accounts(id) ON DELETE SET NULL,
    action text NOT NULL,
    subject_id uuid,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS bright_identity_audit_account_time
    ON bright_identity_audit(account_id, occurred_at DESC);
