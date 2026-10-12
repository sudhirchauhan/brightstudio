CREATE UNIQUE INDEX bright_focus_one_open ON bright_focus_sessions(owner_id) WHERE state IN ('active','paused');
