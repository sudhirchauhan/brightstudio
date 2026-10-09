ALTER TABLE bright_sources ADD CONSTRAINT bright_sources_id_owner_unique UNIQUE(id,owner_id);
