CREATE TABLE bright_study_starts (
 pass_id TEXT NOT NULL,
 owner_id TEXT NOT NULL,
 idempotency_key text NOT NULL,
 FOREIGN KEY(pass_id,owner_id) REFERENCES bright_study_passes(id,owner_id),
 PRIMARY KEY(owner_id,idempotency_key)
);
