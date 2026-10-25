# Firestore document schema v1

Project: `mobileapp-db88e`, database: `(default)`.
Imported and verified on 25/10/2026 from a fresh read-only Aiven snapshot.
All 316 source rows are represented: 207 standalone documents plus 109 embedded
rows. The original staging import and Aiven data remain intact.

## Browse in Firebase Console

Return to the database root using the Home icon, then open a collection below.
Document IDs are original application IDs, such as `staff-01`, not staging hashes.
Choose a document to see its fields directly. Collections with zero documents
will not be visible until a real document is added; no placeholder data was added.

| Collection | Documents | Source / nested data |
| --- | ---: | --- |
| users | 24 | User fields + specializedCategoryIds (41 source links total) |
| auth_credentials | 19 | Keyed by userId; original passwordHash and tokenVersion |
| branches | 4 | Branch fields + settings map (4 shop_settings rows) |
| categories | 6 | Shared categories, original IDs |
| services | 20 | Catalog with integer priceVnd and durationMinutes |
| appointments | 64 | Appointment fields + ordered services array (64 source items), serviceIds array |
| staff_shifts | 70 | Staff/branch IDs and timestamp intervals |
| staff_leave_requests | 0 | Schema supported, source empty |
| promotions | 0 | Schema supported, source empty |
| reviews | 0 | Schema supported; ID appointmentId__targetType, source empty |

The `_migrations/aiven-nosql-v1` document records counts, checksums, embedded-row
counts and completion status. It is operational metadata, not application data.

## Field mapping and types

Original snake_case column names become camelCase. No source columns are omitted.
Examples: branch_id -> branchId, total_price_vnd -> totalPriceVnd,
service_name_snapshot -> serviceNameSnapshot. IDs, role values (`superAdmin`,
`manager`, `staff`, `customer`), approvals, independent hidden flags, legacy review
flags and all historical snapshots remain unchanged.

TIMESTAMPTZ becomes native Firestore Timestamp with PostgreSQL microseconds
retained, interpreted as an absolute UTC instant. DATE/DATE[] remain calendar
strings (YYYY-MM-DD), including closedDates and leaveDate; these are not instants.
BIGINT money becomes native Firestore int64, never a floating-point amount. The
Node client must enable useBigInt when reading and stringify money in API JSON
to retain values above JavaScript's safe integer range. Other integer fields
can be converted to Number only after checking their bounds. NUMERIC, if added,
remains exact decimal text until an explicit decimal mapping is designed.

`appointments/{id}.services` holds the full original appointment-service rows,
including appointmentId, position, serviceId and serviceNameSnapshot. Items are
sorted by position and serviceIds follows the same order. Historical names and
totalPriceVnd are not recalculated from the current catalog.

`users/{id}.specializedCategoryIds` is the sorted list of category IDs from
staff_specializations. Non-staff users have an empty array.

`branches/{id}.settings` retains every shop_settings field, including its original
id and branchId, openingMinute, closingMinute, closedWeekdays and closedDates.

Reviews remain independently queryable by targetType/targetId/customerId. Shifts,
leave requests and appointments are separate collections instead of unbounded
arrays in user/branch documents.

Credentials are a private collection, not embedded in public profiles. Original
hashes and token versions are retained; no plaintext password is generated or
logged. Client rules currently deny all access; NestJS Admin SDK will use IAM.

## Migration tooling

From backend/:

* `node migrate-nosql.cjs` validates/transforms a consistent read-only source
  snapshot and prints counts; it makes no Firestore connection.
* `node migrate-nosql.cjs --write` requires explicit FIREBASE_PROJECT_ID,
  FIRESTORE_DATABASE_ID and Application Default Credentials. It checks deny-all
  client rules, rejects nonempty target collections, and creates every document
  plus the migration marker in one atomic batch. It supports up to 450 target
  documents; larger datasets must use a different import strategy.
* `node migrate-nosql.cjs --verify` independently reads every target collection
  and compares document IDs, counts and canonical SHA-256 content checksums
  against the committed manifest. It updates the verification timestamp/status.

Writes use create preconditions and a fixed migration marker. Rerunning --write
will fail rather than overwrite operational data. If the batch committed but
read-back was interrupted, use --verify. SQL timestamp/date arrays are read as
text arrays, avoiding local timezone conversions by the pg default parser.

## Runtime status

This completes data reshaping/import only. NestJS still uses PostgreSQL/TypeORM;
Flutter has not been changed. Further Aiven writes are not replicated into these
documents. A final synchronized snapshot is required when cutting over.

Before enabling Firestore runtime, implement and test all feature adapters,
role/branch/ownership checks, JWT token revocation, email/manager uniqueness,
atomic staff approval, state transitions, reference checks and booking/leave/shift
serialization. SQL triggers, foreign keys and exclusion constraints do not execute
in Firestore. Define/deploy composite indexes to match the actual adapter queries,
including appointments by role scope/status/startAt, shifts/leave by staff/branch
and time, and reviews by target/time. Do not change runtime configuration merely
because the import is verified.
