-- Approved Phase3 interval leave/Boss decisions. Run after 004, never synchronize.
BEGIN;
ALTER TABLE staff_leave_requests ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ;
ALTER TABLE staff_leave_requests ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ;
ALTER TABLE staff_leave_requests ADD COLUMN IF NOT EXISTS reason TEXT NOT NULL DEFAULT '';
-- Legacy dates represent full Hanoi calendar days; preserve existing decisions.
ALTER TABLE staff_leave_requests DISABLE TRIGGER leave_record;
UPDATE staff_leave_requests SET
  start_at=leave_date::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh',
  end_at=(leave_date+1)::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh'
WHERE start_at IS NULL OR end_at IS NULL;
ALTER TABLE staff_leave_requests ALTER COLUMN start_at SET NOT NULL;
ALTER TABLE staff_leave_requests ALTER COLUMN end_at SET NOT NULL;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='staff_leave_requests'::regclass AND conname='leave_interval_valid') THEN
  ALTER TABLE staff_leave_requests ADD CONSTRAINT leave_interval_valid CHECK(end_at>start_at);
 END IF;
END $$;
-- Replace per-day uniqueness: permit distinct partial-day requests, reject overlap.
DROP INDEX IF EXISTS leave_active_date_idx;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='staff_leave_requests'::regclass AND conname='leave_no_overlap') THEN
  ALTER TABLE staff_leave_requests ADD CONSTRAINT leave_no_overlap EXCLUDE USING gist
   (staff_id WITH =,tstzrange(start_at,end_at,'[)') WITH &&) WHERE(status IN ('pending','approved'));
 END IF;
END $$;
CREATE INDEX IF NOT EXISTS leave_staff_interval_idx ON staff_leave_requests(staff_id,branch_id,start_at,end_at) WHERE status='approved';
CREATE OR REPLACE FUNCTION validate_leave_record() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE person users%ROWTYPE; branch_name TEXT;
BEGIN
 IF TG_OP='INSERT' THEN
  IF NEW.status<>'pending' THEN RAISE EXCEPTION 'New leave must be pending'; END IF;
  SELECT * INTO person FROM users WHERE id=NEW.staff_id FOR SHARE;
  IF NOT FOUND OR person.role<>'staff' OR NOT person.is_approved OR person.branch_id<>NEW.branch_id THEN RAISE EXCEPTION 'Approved Staff of this branch required'; END IF;
  IF NEW.end_at<=CURRENT_TIMESTAMP OR NEW.start_at<(date_trunc('day',CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh') AT TIME ZONE 'Asia/Ho_Chi_Minh') THEN RAISE EXCEPTION 'Leave is in the past'; END IF;
  IF btrim(NEW.reason)='' THEN RAISE EXCEPTION 'Leave reason required'; END IF;
  NEW.staff_name:=person.name;
  NEW.leave_date:=(NEW.start_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
 ELSE
  IF OLD.status<>'pending' THEN RAISE EXCEPTION 'Leave decision history is immutable'; END IF;
  IF ROW(NEW.id,NEW.staff_id,NEW.staff_name,NEW.branch_id,NEW.leave_date,NEW.created_at,NEW.start_at,NEW.end_at,NEW.reason)
     IS DISTINCT FROM ROW(OLD.id,OLD.staff_id,OLD.staff_name,OLD.branch_id,OLD.leave_date,OLD.created_at,OLD.start_at,OLD.end_at,OLD.reason) THEN RAISE EXCEPTION 'Leave fields are immutable'; END IF;
  IF NEW.status NOT IN ('approved','rejected') THEN RAISE EXCEPTION 'Decision required'; END IF;
  SELECT * INTO person FROM users WHERE id=NEW.reviewed_by FOR SHARE;
  IF NOT FOUND OR NOT person.is_approved OR NOT (person.role='superAdmin' OR (person.role='manager' AND person.branch_id=NEW.branch_id)) THEN RAISE EXCEPTION 'Boss or branch Manager required'; END IF;
  SELECT name INTO branch_name FROM branches WHERE id=NEW.branch_id;
  NEW.reviewed_by_name:=person.name;NEW.reviewed_branch_name:=branch_name;NEW.reviewed_at:=clock_timestamp();
 END IF;
 RETURN NEW;
END $$;
ALTER TABLE staff_leave_requests ENABLE TRIGGER leave_record;
COMMIT;
