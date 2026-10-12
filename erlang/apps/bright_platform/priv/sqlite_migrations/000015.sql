CREATE TABLE bright_evidence_links (
 board_id TEXT NOT NULL,
 evidence_id TEXT NOT NULL,
 owner_id TEXT NOT NULL,
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f','now')),
 PRIMARY KEY(board_id,evidence_id),
 FOREIGN KEY(board_id,owner_id) REFERENCES bright_evidence_boards(id,owner_id),
 FOREIGN KEY(evidence_id,owner_id) REFERENCES bright_evidence(id,owner_id)
);
