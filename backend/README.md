# Backend NestJS + Cloud Firestore

Backend uses Firebase Admin SDK and JWT authentication. It does not require a SQL
server, database password or CA certificate. Run commands from this directory.

1. `npm ci`
2. Copy `.env.example` to `.env` and configure the Firebase project, database,
   backend credentials (Google ADC or a service account outside this repository),
   and a stable random JWT_SECRET of at least 32 characters.
3. `npm start`

Public catalog smoke check: `GET http://localhost:3000/api/branches`.

- `npm test`: offline service, HTTP and data contract tests.
- `npm run test:firestore:live`: full NestJS/Firestore integration in a fresh isolated
  namespace, with cleanup. Requires Firebase credentials and network access.
- `node verify-firestore-runtime.cjs`: optional read-only comparison with the
  historical import checksum manifest, plus public HTTP smoke checks. Real app
  writes will naturally change the historical checksums.

See [FIRESTORE_RUNTIME.md](FIRESTORE_RUNTIME.md) for setup, transaction constraints,
scaling limits and deployment; [FIRESTORE_NOSQL_SCHEMA.md](FIRESTORE_NOSQL_SCHEMA.md)
for collection mappings. Flutter live test cleanup uses
`cleanup-flutter-fixture.cjs`, restricted to the test fixture identity.
