CREATE TABLE IF NOT EXISTS bright_memberships (
  user_id uuid NOT NULL REFERENCES bright_users(id) ON DELETE CASCADE,
  workspace_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('owner', 'admin', 'editor', 'viewer')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, workspace_id)
);