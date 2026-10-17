-- Demo appointments shared by customers, Manager and Boss reports.
-- Run after 003. Existing rows, credentials and appointment edits are preserved.
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('ktgk-demo-seed'));
DO $$
DECLARE person RECORD; month_offset INTEGER; visit INTEGER; starts TIMESTAMPTZ;
  demo_id TEXT; customer RECORD; service RECORD;
BEGIN
  SELECT id,name,price_vnd,duration_minutes INTO STRICT service FROM services WHERE id='service-01';
  FOR person IN SELECT id,branch_id FROM users WHERE role='staff' AND is_approved ORDER BY id LOOP
    FOR month_offset IN 0..1 LOOP
      FOR visit IN 1..3 LOOP
        SELECT id,name INTO STRICT customer FROM users WHERE id='customer-0'||visit;
        starts := (date_trunc('month', CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')
          - make_interval(months => month_offset) + make_interval(days => visit, hours => 10)) AT TIME ZONE 'Asia/Ho_Chi_Minh';
        -- Only seed completed visits in the past; never complete a future booking.
        IF starts + make_interval(mins => service.duration_minutes) > CURRENT_TIMESTAMP THEN CONTINUE; END IF;
        demo_id := 'demo-visit-'||person.id||'-'||to_char(starts AT TIME ZONE 'Asia/Ho_Chi_Minh','YYYY-MM')||'-'||visit;
        IF EXISTS(SELECT 1 FROM appointments WHERE id=demo_id) THEN CONTINUE; END IF;
        IF EXISTS(SELECT 1 FROM appointments WHERE staff_id=person.id AND status IN ('pending','confirmed','completed')
          AND tstzrange(start_at,end_at,'[)') && tstzrange(starts,starts+make_interval(mins=>service.duration_minutes),'[)')) THEN CONTINUE; END IF;
        INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status)
          VALUES(demo_id,person.branch_id,person.id,customer.id,customer.name,starts,
            starts+make_interval(mins=>service.duration_minutes),service.price_vnd,'completed');
        INSERT INTO appointment_services(appointment_id,position,service_id,service_name_snapshot)
          VALUES(demo_id,0,service.id,service.name);
      END LOOP;
    END LOOP;
  END LOOP;
END $$;
COMMIT;
