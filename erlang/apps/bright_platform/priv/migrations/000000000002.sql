CREATE TABLE IF NOT EXISTS bright_users (
  id uuid PRIMARY KEY,
  email text NOT NULL UNIQUE,
  display_name text NOT NULL DEFAULT '',
  disabled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bright_users_email_not_empty CHECK (length(trim(email)) > 0)
);