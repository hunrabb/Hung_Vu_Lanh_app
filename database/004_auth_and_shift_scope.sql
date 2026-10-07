-- Approved manual migration. No TypeORM schema synchronization.
BEGIN;
ALTER TABLE auth_credentials ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0;
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='auth_credentials'::regclass AND conname='credential_token_version_nonnegative') THEN
    ALTER TABLE auth_credentials ADD CONSTRAINT credential_token_version_nonnegative CHECK(token_version>=0);
  END IF;
END $$;
ALTER TABLE staff_shifts ADD COLUMN IF NOT EXISTS branch_id TEXT;
DO $$ BEGIN
  IF EXISTS(SELECT 1 FROM staff_shifts WHERE branch_id IS NULL) THEN
    RAISE EXCEPTION 'Existing shifts need explicit historical branch mapping before this migration';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='staff_shifts'::regclass AND conname='staff_shifts_branch_scope_fk') THEN
    ALTER TABLE staff_shifts ADD CONSTRAINT staff_shifts_branch_scope_fk FOREIGN KEY(branch_id) REFERENCES branches(id) ON DELETE RESTRICT;
  END IF;
END $$;
ALTER TABLE staff_shifts ALTER COLUMN branch_id SET NOT NULL;
CREATE INDEX IF NOT EXISTS staff_shifts_branch_time_idx ON staff_shifts(branch_id,start_at);
COMMIT;
