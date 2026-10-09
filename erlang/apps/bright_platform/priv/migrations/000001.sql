-- Bootstrap only: no product tables or legacy data assumptions.
CREATE TABLE IF NOT EXISTS bright_platform_audit (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_type text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
