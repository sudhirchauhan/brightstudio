ALTER TABLE bright_users ADD COLUMN profile_version integer NOT NULL DEFAULT 1 CHECK(profile_version>0);
