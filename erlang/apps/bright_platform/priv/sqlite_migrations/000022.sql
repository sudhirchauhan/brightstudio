CREATE TABLE bright_tasks (
 id TEXT PRIMARY KEY,
 owner_id TEXT NOT NULL,
 project_id TEXT NOT NULL,
 title text NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
 note text NOT NULL DEFAULT '',
 state text NOT NULL DEFAULT 'todo' CHECK(state IN ('todo','doing','done')),
 due_date text NOT NULL DEFAULT '',
 scheduled_date text NOT NULL DEFAULT '',
 estimate_minutes integer NOT NULL DEFAULT 25 CHECK(estimate_minutes BETWEEN 5 AND 480),
 priority integer NOT NULL DEFAULT 2 CHECK(priority BETWEEN 1 AND 3),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 completed_at TEXT,
 FOREIGN KEY(project_id,owner_id) REFERENCES bright_projects(id,owner_id),
 UNIQUE(id,owner_id)
);
