# Aiven to Firestore preparation

## NoSQL import completed — 25/10/2026

In addition to the raw staging copy below, a fresh Aiven snapshot has now been
converted to native top-level collections. All 316 rows are represented by 207
documents and 109 embedded rows. The atomic import and content/count checks passed.
See FIRESTORE_NOSQL_SCHEMA.md for collection/field mappings and verification CLI.
Migration record: `_migrations/aiven-nosql-v1`. NestJS still uses PostgreSQL.

## Earlier raw staging copy

Selected architecture: Flutter -> NestJS -> Firestore, keeping NestJS JWT auth.
Credential project ID: mobileapp-db88e. User selected database ID: (default).
IAM permissions are now effective; deployed client rules deny all reads/writes.
On 25/10/2026, 13 public tables with 316 total rows were copied and every row/count
verified under `aiven_imports/3c126d9e-1064-42b9-85fc-8a5dfb3f72bc` in (default).
The run status is verified. Zero-row tables appear in the run manifest only;
Firestore does not materialize empty collections. Aiven was not modified.
The API still uses PostgreSQL. This tool prepares staging data, not API cutover.

Set FIREBASE_PROJECT_ID and FIRESTORE_DATABASE_ID in backend/.env. Confirm whether
the database ID is (default) or a named database in Console. Use Application
Default Credentials or GOOGLE_APPLICATION_CREDENTIALS pointing to a service
account JSON outside the repository. Never paste private keys into chat.

Before importing, deny all client access to aiven_imports and remove any matching
broad allow/test-mode rules. The snapshot contains password hashes and personal
data. Admin SDK uses IAM and bypasses client Security Rules. The service account
needs read/write IAM access to the target database.

From backend/: `node migrate-firestore.cjs` runs a read-only repeatable-read
snapshot of every public base table, validates values and prints counts only.
It does not connect to Firestore or export data locally.

`node migrate-firestore.cjs --write` creates a new UUID staging run under
aiven_imports/{runId}/{table}/{hashedPrimaryKey}. Original columns, primary-key
values, foreign-key values and password hashes are retained. Dates/timestamps,
BIGINT and NUMERIC stay as PostgreSQL text to avoid precision loss. Composite
primary keys get deterministic SHA-256 document IDs. Missing keys, unsafe numeric
values, binary data and nested arrays fail instead of silently losing data.

Each table count and every field is read back before marking the run verified.
Failed runs may contain partial copies; reruns use a new ID without overwriting.
The entire snapshot is loaded in RAM, suitable for this small app database only.
This is not a schema backup: SQL indexes, triggers, constraints and functions must
be replaced in NestJS. It does not replicate changes made after the snapshot.

Before cutover: implement all Firestore data adapters, preserve authorization and
uniqueness, implement atomic booking locks, map staging values to the operational
schema, deploy indexes, and run API/concurrency tests. Pause source writes for the
final import, verify it, then switch NestJS. Keep Aiven as rollback source.

Official references:
https://firebase.google.com/docs/admin/setup
https://firebase.google.com/docs/firestore/manage-databases
