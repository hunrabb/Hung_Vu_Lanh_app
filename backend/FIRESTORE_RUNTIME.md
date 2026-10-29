# Firestore runtime

The backend now runs Flutter -> NestJS/JWT -> Firestore. AppModule connects only
to Firestore. Legacy SQL schema, seed, migration scripts,
live tests and SQL client dependencies have been removed from this checkout.

## Local run

Use Node >=22.12. From backend/, run `npm ci`, copy `.env.example` to `.env`, set
FIREBASE_PROJECT_ID, FIRESTORE_DATABASE_ID, GOOGLE_APPLICATION_CREDENTIALS and a
stable random JWT_SECRET of at least 32 characters, then `npm start`.
The credential file stays outside the repository and is never shipped in Flutter.
On managed Google infrastructure, use its service identity/ADC instead.

Existing local configuration targets mobileapp-db88e/(default). `.env` is ignored.
Runtime uses the already imported collections; it does not recopy PostgreSQL.
Later PostgreSQL writes since the 25/10 snapshot are NOT automatically included.
Keep the old database available until the owner confirms there are no later
source writes to reconcile. No remote Aiven database has been deleted.

## Data and constraints

Users embed specializedCategoryIds; branches embed settings; appointments embed
ordered services and serviceIds. Credentials remain a separate private collection.
Services map priceVnd/durationMinutes to API price/duration; reviews map targetType
to API target. Money stays Firestore int64 and API decimal strings. Dates are UTC
instants; closedDates remains calendar strings. Unchanged fields are not rewritten,
so imported microsecond timestamps are preserved during unrelated updates.

All mutations read current user/credential and enforce role/branch/ownership and
JWT tokenVersion inside the transaction. User/credential creation and approval are
atomic. Email uniqueness, references, shift/leave overlap, review uniqueness and
appointment state transitions are validated in the same snapshot. A shared
`_runtime/constraints` document serializes all backend writes, including inserts
whose conflict query was initially empty. Firestore performs transaction retries.
No client may bypass these checks: retain deny-all client Firestore rules and
restrict Admin IAM credentials to the backend. Console/Admin writes are privileged
and must preserve the same schema and invariants.

## Scale limits

This first runtime deliberately reads whole relevant collections inside a snapshot
and filters/sorts/paginates in the backend. It fits the current small coursework
sample, requires no composite indexes, and does not cache personal data between
requests. It is NOT intended for large datasets/high write throughput. Read billing
increases with collection size; the shared fence serializes unrelated writes.
Before expanding, replace scans with scoped indexed queries and partitioned
uniqueness/calendar locks, retaining the existing concurrency/contract tests.
API pagination currently limits responses, not Firestore reads.

## Validation

`npm test`: offline unit/HTTP contracts, runtime mapping, checksum precision and fixture cleanup protection.
`npm run test:firestore:live`: real Firestore/NestJS integration, creates a unique
`_test_runs/runtime-<uuid>/...` namespace, then deletes only its own documents in
finally. It exercises HTTP login/JWT, int64, simultaneous bookings and duplicate
emails, shift protection, immutable leave history, reviews, approval, reports and
revocation. Never set FIRESTORE_TEST_RUN_ID for normal app usage.

`node verify-firestore-runtime.cjs`: read-only production checksum/count comparison
against the existing migration manifest and a public HTTP catalog smoke test.
Checksums are expected to differ after real application writes begin; the old
migration manifest describes the historical snapshot, not ongoing runtime health.

For friends on other machines, deploy NestJS to a reachable HTTPS host and build
Flutter with --dart-define=API_BASE_URL=https://your-api.example.com/api. Keep the
same Firestore project and a stable server JWT secret. Copying source alone does
not make localhost point to another computer. This task does not deploy a server
or migrate the Flutter screens still intentionally backed by RAM mock providers.
