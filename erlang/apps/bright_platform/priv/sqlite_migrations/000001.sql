-- Bootstrap only: no product tables or legacy data assumptions.
CREATE TABLE IF NOT EXISTS bright_platform_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type text NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now'))
);
