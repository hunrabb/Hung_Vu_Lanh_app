-- Run after 001_core_postgresql.sql to retain existing Promotion, StaffShift,
-- and LeaveRequest features when replacing RAM. No revenue/commission tables.
BEGIN;
CREATE TABLE promotions (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  image_url TEXT NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE staff_shifts (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  staff_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  CHECK (end_at > start_at)
);
CREATE TRIGGER shift_owner BEFORE INSERT OR UPDATE ON staff_shifts
  FOR EACH ROW EXECUTE FUNCTION validate_specialization_owner();

CREATE TABLE staff_leave_requests (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  staff_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  staff_name TEXT NOT NULL CHECK (btrim(staff_name) <> ''),
  branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  leave_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  reviewed_by TEXT REFERENCES users(id) ON DELETE RESTRICT,
  reviewed_by_name TEXT,
  reviewed_branch_name TEXT,
  reviewed_at TIMESTAMPTZ,
  note TEXT NOT NULL DEFAULT '',
  CHECK (
    (status='pending' AND reviewed_by IS NULL AND reviewed_by_name IS NULL
      AND reviewed_branch_name IS NULL AND reviewed_at IS NULL)
    OR (status IN ('approved','rejected') AND reviewed_by IS NOT NULL
      AND reviewed_by_name IS NOT NULL AND btrim(reviewed_by_name) <> ''
      AND reviewed_branch_name IS NOT NULL AND btrim(reviewed_branch_name) <> ''
      AND reviewed_at IS NOT NULL AND reviewed_at >= created_at)
  )
);
CREATE UNIQUE INDEX leave_active_date_idx ON staff_leave_requests(staff_id,branch_id,leave_date)
  WHERE status IN ('pending','approved');
CREATE INDEX leave_branch_status_idx ON staff_leave_requests(branch_id,status,created_at DESC);

CREATE FUNCTION validate_leave_record() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE person users%ROWTYPE; branch_name TEXT;
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.status <> 'pending' THEN RAISE EXCEPTION 'New leave request must be pending'; END IF;
    SELECT * INTO person FROM users WHERE id=NEW.staff_id FOR SHARE;
    IF NOT FOUND OR person.role <> 'staff' OR NOT person.is_approved OR person.branch_id <> NEW.branch_id THEN
      RAISE EXCEPTION 'Leave requires approved Staff in this branch';
    END IF;
    IF NEW.leave_date < (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date THEN
      RAISE EXCEPTION 'Cannot request leave in the past';
    END IF;
    NEW.staff_name := person.name;
  ELSE
    IF OLD.status <> 'pending' THEN RAISE EXCEPTION 'Leave decision history is immutable'; END IF;
    IF ROW(NEW.id,NEW.staff_id,NEW.staff_name,NEW.branch_id,NEW.leave_date,NEW.created_at)
       IS DISTINCT FROM ROW(OLD.id,OLD.staff_id,OLD.staff_name,OLD.branch_id,OLD.leave_date,OLD.created_at) THEN
      RAISE EXCEPTION 'Leave identity/snapshots cannot be modified';
    END IF;
    IF NEW.status NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Decision required'; END IF;
    SELECT * INTO person FROM users WHERE id=NEW.reviewed_by FOR SHARE;
    IF NOT FOUND OR person.role <> 'manager' OR person.branch_id <> NEW.branch_id THEN
      RAISE EXCEPTION 'Reviewer must be a Manager of this branch';
    END IF;
    SELECT name INTO branch_name FROM branches WHERE id=NEW.branch_id;
    NEW.reviewed_by_name := person.name;
    NEW.reviewed_branch_name := branch_name;
    NEW.reviewed_at := clock_timestamp();
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER leave_record BEFORE INSERT OR UPDATE ON staff_leave_requests
  FOR EACH ROW EXECUTE FUNCTION validate_leave_record();

REVOKE ALL ON promotions,staff_shifts,staff_leave_requests FROM PUBLIC;
COMMIT;
