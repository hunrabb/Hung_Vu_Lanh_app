-- Additive migration after 005. Does not change existing appointments or accounts.
BEGIN;
CREATE UNIQUE INDEX IF NOT EXISTS users_one_manager_per_branch
  ON users(branch_id) WHERE role='manager';
CREATE TABLE IF NOT EXISTS reviews (
  appointment_id TEXT NOT NULL REFERENCES appointments(id) ON DELETE RESTRICT,
  target_type TEXT NOT NULL CHECK (target_type IN ('branch','staff')),
  target_id TEXT NOT NULL,
  customer_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT NOT NULL DEFAULT '' CHECK (length(comment)<=1000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (appointment_id,target_type)
);
CREATE INDEX IF NOT EXISTS reviews_target_created_idx ON reviews(target_type,target_id,created_at DESC);
-- Validate the polymorphic target against the actual completed appointment.
CREATE OR REPLACE FUNCTION validate_customer_review() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE a appointments%ROWTYPE;
BEGIN
  SELECT * INTO a FROM appointments WHERE id=NEW.appointment_id FOR UPDATE;
  IF NOT FOUND OR a.status<>'completed' OR a.customer_id IS DISTINCT FROM NEW.customer_id
    OR NEW.target_id IS DISTINCT FROM (CASE WHEN NEW.target_type='branch' THEN a.branch_id ELSE a.staff_id END)
  THEN RAISE EXCEPTION 'Review must match an owned completed appointment' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS validate_customer_review ON reviews;
CREATE TRIGGER validate_customer_review BEFORE INSERT OR UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION validate_customer_review();
COMMIT;
