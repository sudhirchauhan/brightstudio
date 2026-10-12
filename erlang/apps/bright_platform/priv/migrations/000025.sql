CREATE TABLE bright_focus_checkpoints (
 session_id uuid NOT NULL,
 owner_id uuid NOT NULL,
 ordinal integer NOT NULL CHECK(ordinal BETWEEN 1 AND 20),
 note text NOT NULL CHECK(length(trim(note)) BETWEEN 10 AND 2000),
 evidence_id uuid,
 elapsed_ms bigint NOT NULL CHECK(elapsed_ms>=0),
 created_at_ms bigint NOT NULL,
 FOREIGN KEY(session_id,owner_id) REFERENCES bright_focus_sessions(id,owner_id),
 FOREIGN KEY(evidence_id,owner_id) REFERENCES bright_evidence(id,owner_id),
 PRIMARY KEY(session_id,ordinal)
);
