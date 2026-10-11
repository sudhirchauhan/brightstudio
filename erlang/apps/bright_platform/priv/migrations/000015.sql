CREATE TABLE bright_evidence_links (
 board_id uuid NOT NULL,
 evidence_id uuid NOT NULL,
 owner_id uuid NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(board_id,evidence_id),
 FOREIGN KEY(board_id,owner_id) REFERENCES bright_evidence_boards(id,owner_id),
 FOREIGN KEY(evidence_id,owner_id) REFERENCES bright_evidence(id,owner_id)
);
