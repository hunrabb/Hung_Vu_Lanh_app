-- Aiven PostgreSQL. Fresh schema, execute ONCE with a migration account.
-- IDs are TEXT to preserve existing Dart IDs (staff-01, customer-01, ...).
-- Application permissions/JWT are enforced by the backend, not by these CHECKs.
BEGIN;
SET LOCAL TIME ZONE 'UTC';
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE branches (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  name TEXT NOT NULL CHECK (btrim(name) <> ''),
  address TEXT NOT NULL CHECK (btrim(address) <> ''),
  phone TEXT NOT NULL CHECK (btrim(phone) <> '')
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY CHECK (id IN ('haircut','massage','hairWash','perm','dye','shaving')),
  name TEXT NOT NULL CHECK (btrim(name) <> '')
);
INSERT INTO categories(id,name) VALUES
  ('haircut','Cắt tóc'), ('massage','Massage'), ('hairWash','Gội đầu'),
  ('perm','Uốn tóc'), ('dye','Nhuộm tóc'), ('shaving','Cạo râu');

CREATE TABLE users (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  name TEXT NOT NULL CHECK (btrim(name) <> ''),
  email TEXT NOT NULL UNIQUE CHECK (
    email = lower(btrim(email)) AND email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  role TEXT NOT NULL DEFAULT 'customer'
    CHECK (role IN ('superAdmin','manager','staff','customer')),
  branch_id TEXT REFERENCES branches(id) ON DELETE RESTRICT,
  phone TEXT,
  address TEXT,
  is_approved BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  loyalty_points INTEGER NOT NULL DEFAULT 0 CHECK (loyalty_points >= 0),
  average_rating DOUBLE PRECISION CHECK (average_rating >= 0 AND average_rating <= 5),
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT user_branch_scope CHECK (
    (role IN ('staff','manager') AND branch_id IS NOT NULL)
    OR (role IN ('superAdmin','customer') AND branch_id IS NULL)
  ),
  CONSTRAINT non_staff_approval CHECK (role = 'staff' OR is_approved)
);
CREATE INDEX users_branch_role_idx ON users(branch_id, role);

-- Credential hashes stay server-side. Never serialize this table to Flutter.
CREATE TABLE auth_credentials (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  password_hash TEXT NOT NULL CHECK (btrim(password_hash) <> '')
);
CREATE FUNCTION protect_credential_identity() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.user_id <> OLD.user_id THEN RAISE EXCEPTION 'Credentials cannot move between identities'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER credential_identity BEFORE UPDATE OF user_id ON auth_credentials
  FOR EACH ROW EXECUTE FUNCTION protect_credential_identity();

CREATE TABLE services (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  name TEXT NOT NULL CHECK (btrim(name) <> ''),
  category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  price_vnd BIGINT NOT NULL CHECK (price_vnd >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE staff_specializations (
  staff_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  PRIMARY KEY (staff_id, category_id)
);

CREATE TABLE shop_settings (
  branch_id TEXT PRIMARY KEY REFERENCES branches(id) ON DELETE RESTRICT,
  id TEXT NOT NULL DEFAULT 'default', -- model ID is not globally unique
  opening_minute SMALLINT NOT NULL CHECK (opening_minute >= 0),
  closing_minute SMALLINT NOT NULL CHECK (closing_minute <= 1440),
  closed_weekdays SMALLINT[] NOT NULL DEFAULT '{}',
  closed_dates DATE[] NOT NULL DEFAULT '{}',
  CHECK (closing_minute > opening_minute),
  CHECK (closed_weekdays <@ ARRAY[1,2,3,4,5,6,7]::SMALLINT[]),
  CHECK (array_position(closed_weekdays,NULL) IS NULL),
  CHECK (array_position(closed_dates,NULL) IS NULL),
  CHECK (cardinality(closed_weekdays)=0 OR array_ndims(closed_weekdays)=1),
  CHECK (cardinality(closed_dates)=0 OR array_ndims(closed_dates)=1)
);

CREATE TABLE appointments (
  id TEXT PRIMARY KEY CHECK (btrim(id) <> ''),
  branch_id TEXT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  staff_id TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  customer_id TEXT REFERENCES users(id) ON DELETE RESTRICT,
  customer_name TEXT NOT NULL DEFAULT '',
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  total_price_vnd BIGINT NOT NULL CHECK (total_price_vnd >= 0),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','confirmed','completed','cancelled','noShow')),
  is_hidden_by_customer BOOLEAN NOT NULL DEFAULT FALSE,
  is_hidden_by_staff BOOLEAN NOT NULL DEFAULT FALSE,
  is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
  rating SMALLINT CHECK (rating BETWEEN 1 AND 5),
  CHECK (end_at > start_at),
  CHECK (customer_id IS NOT NULL OR btrim(customer_name) <> ''),
  CHECK (NOT is_reviewed OR rating IS NOT NULL),
  -- Exactly the current TimeSlot/blocksTime rule, including completed history.
  CONSTRAINT staff_no_overlap EXCLUDE USING gist (
    staff_id WITH =, tstzrange(start_at,end_at,'[)') WITH &&
  ) WHERE (status IN ('pending','confirmed','completed'))
);
CREATE INDEX appointments_branch_time_idx ON appointments(branch_id,start_at);
CREATE INDEX appointments_customer_time_idx ON appointments(customer_id,start_at DESC);
CREATE INDEX appointments_staff_time_idx ON appointments(staff_id,start_at DESC);
CREATE INDEX appointments_completed_branch_idx ON appointments(branch_id,start_at)
  WHERE status='completed';

-- Maintains ordering and BOTH existing Dart lists without parallel SQL arrays.
CREATE TABLE appointment_services (
  appointment_id TEXT NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 0),
  service_id TEXT NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
  service_name_snapshot TEXT NOT NULL CHECK (btrim(service_name_snapshot) <> ''),
  PRIMARY KEY (appointment_id,position)
);
CREATE INDEX appointment_services_service_idx ON appointment_services(service_id);

-- Approved users must have a credential; pending/revoked Staff must not.
-- Deferred so Boss approval can write credentials and approval in ONE transaction.
CREATE FUNCTION check_auth_consistency() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE uid TEXT; approved BOOLEAN; present BOOLEAN;
BEGIN
  IF TG_TABLE_NAME='users' THEN
    uid := COALESCE(NEW.id,OLD.id);
  ELSE
    uid := COALESCE(NEW.user_id,OLD.user_id);
  END IF;
  SELECT is_approved INTO approved FROM users WHERE id=uid;
  IF NOT FOUND THEN RETURN NULL; END IF;
  SELECT EXISTS(SELECT 1 FROM auth_credentials WHERE user_id=uid) INTO present;
  IF approved <> present THEN
    RAISE EXCEPTION 'Approval and credential must be committed together for user %',uid;
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER users_auth_consistency
  AFTER INSERT OR UPDATE ON users DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION check_auth_consistency();
CREATE CONSTRAINT TRIGGER credentials_auth_consistency
  AFTER INSERT OR UPDATE OR DELETE ON auth_credentials DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION check_auth_consistency();

CREATE FUNCTION validate_appointment_people() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE staff users%ROWTYPE; customer_role TEXT;
BEGIN
  -- Do not revalidate branch/approval during completion/hide: history stays put
  -- even if Staff later moves branch or loses approval.
  IF TG_OP='UPDATE' AND NEW.branch_id=OLD.branch_id AND NEW.staff_id=OLD.staff_id
     AND NEW.customer_id IS NOT DISTINCT FROM OLD.customer_id
     AND NEW.start_at=OLD.start_at AND NEW.end_at=OLD.end_at THEN
    RETURN NEW;
  END IF;
  SELECT * INTO staff FROM users WHERE id=NEW.staff_id FOR SHARE;
  IF NOT FOUND OR staff.role <> 'staff' OR NOT staff.is_approved OR staff.branch_id <> NEW.branch_id THEN
    RAISE EXCEPTION 'Appointment requires approved Staff of the selected branch';
  END IF;
  IF NEW.customer_id IS NOT NULL THEN
    SELECT role INTO customer_role FROM users WHERE id=NEW.customer_id FOR SHARE;
    IF NOT FOUND OR customer_role <> 'customer' THEN RAISE EXCEPTION 'Customer role required'; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER appointment_people BEFORE INSERT OR UPDATE ON appointments
  FOR EACH ROW EXECUTE FUNCTION validate_appointment_people();

CREATE FUNCTION validate_specialization_owner() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE user_role TEXT;
BEGIN
  SELECT role INTO user_role FROM users WHERE id=NEW.staff_id FOR SHARE;
  IF NOT FOUND OR user_role <> 'staff' THEN RAISE EXCEPTION 'Only Staff can have specializations'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER specialization_owner BEFORE INSERT OR UPDATE ON staff_specializations
  FOR EACH ROW EXECUTE FUNCTION validate_specialization_owner();

-- Service/category eligibility must be checked by the booking API while holding
-- Staff/catalog locks, BEFORE insertion. SQL FK preserves historical references.
CREATE FUNCTION require_appointment_services() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE aid TEXT;
BEGIN
  IF TG_TABLE_NAME='appointment_services' AND TG_OP='UPDATE' THEN
    IF NEW.appointment_id <> OLD.appointment_id THEN
      RAISE EXCEPTION 'Service items cannot be moved to another appointment';
    END IF;
  END IF;
  IF TG_TABLE_NAME='appointments' THEN aid := COALESCE(NEW.id,OLD.id);
  ELSE aid := COALESCE(NEW.appointment_id,OLD.appointment_id); END IF;
  IF EXISTS(SELECT 1 FROM appointments WHERE id=aid)
     AND NOT EXISTS(SELECT 1 FROM appointment_services WHERE appointment_id=aid) THEN
    RAISE EXCEPTION 'Appointment must contain at least one service';
  END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER appointment_requires_services AFTER INSERT OR UPDATE ON appointments
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION require_appointment_services();
CREATE CONSTRAINT TRIGGER appointment_items_required AFTER INSERT OR UPDATE OR DELETE ON appointment_services
  DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION require_appointment_services();

-- Active specialization links belong to Staff; historical appointments keep IDs.
CREATE FUNCTION protect_referenced_user_role() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.role <> 'staff' AND EXISTS(SELECT 1 FROM staff_specializations WHERE staff_id=OLD.id)
  THEN RAISE EXCEPTION 'Remove active Staff specializations before changing role'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER referenced_user_role BEFORE UPDATE OF role ON users
  FOR EACH ROW EXECUTE FUNCTION protect_referenced_user_role();

REVOKE ALL ON branches,categories,users,auth_credentials,services,
  staff_specializations,shop_settings,appointments,appointment_services FROM PUBLIC;
-- Grant the future API account explicitly; Flutter receives NO database account.
COMMIT;
