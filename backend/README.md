# KTGK NestJS API

NestJS + TypeORM + pg + @nestjs/config. Run commands from `ktgk/backend`,
since `.env` and `./ca.pem` are resolved relative to the working directory.

1. `npm install`
2. Copy `.env.example` to `.env`, enter actual Aiven connection values/port.
3. Download the project CA from Aiven and place the real certificate at
   `backend/ca.pem`. No fake certificate is included. `.env`/CA are ignored by Git.
4. `npm run build`, then `npm start` (or `npm run start:dev`).
5. `GET http://localhost:3000/api/branches`.

The existing `public.branches` table must already exist. Entity IDs are TEXT
matching database/001_core_postgresql.sql. TLS certificate verification is enabled;
missing CA or invalid env stops startup rather than falling back to insecure TLS.
`synchronize`, `dropSchema`, and `migrationsRun` are false. This API does not
create/alter/seed tables. Database grants must allow the configured API user
SELECT on `public.branches`.

Read routes: `/api/branches`, `/api/categories`, `/api/services`,
`/api/users/pending`, `/api/users/branch/:branchId`. User routes only return Staff
profiles (pending query also requires isApproved=false). Branch IDs are TEXT,
not UUID-only. Services maps price_vnd/duration_minutes to price/duration;
price is a JSON string to preserve PostgreSQL BIGINT precision.

Phase2 adds Manager Staff create/update, Boss approval/rejection, Boss CRUD for
Branches/Services/Categories and tenant-scoped settings PATCH. See PHASE2_TESTING.md
for routes, bodies, validation, six-category schema limit and live smoke test.
No schema synchronization/migration is run automatically.

AuthModule now protects routes globally with JWT and fresh DB profile/token_version.
Users pending is Boss-only; Users branch is Boss or the matching Manager, also
checked inside UsersService. Public routes are login/register and branch/catalog
directories. See AUTH_TESTING.md. Flutter still uses mock repositories.

`node smoke-live.cjs` tests all read routes against the configured real Aiven DB
on an ephemeral localhost port, prints only status/row count and closes the app.

`node seed-data.cjs` runs `../database/003_seed_mock_data.sql` against the configured
DB with TLS. Expanded dataset: 4 Hanoi branches, 1 global superAdmin, 4 Managers,
10 approved Staff, 5 pending Staff, 3 Customers and 20 services. Inserts use ON CONFLICT
DO NOTHING and a transaction; conflicting user IDs/emails abort instead of rebinding
credentials. Re-running does not reset approvals, passwords or service edits;
branch/category demo names and contact details are refreshed by the expanded SQL.
`generate-expanded-seed.cjs` regenerates SQL while preserving existing seed hashes.
`verify-expanded-seed.cjs` checks real counts, Staff distribution and HTTP endpoints.
Category IDs remain the six Flutter enum values; Combo VIP is a service under
haircut, not a seventh category. Renamed category display labels will require
Flutter to read category names from the API rather than its old label helper.

Test-only passwords: boss123 for Boss, admin123 for admin-01, manager123 for other
Managers, staff123 for approved Staff, customer123 for Customers. Pending Staff
have no credential. Hashes use Node scrypt
N=131072,r=8,p=1 with random salts, encoded as $scrypt$N$r$p$saltHex$hashHex.
The first run materializes hashes in the SQL file so psql can re-run it directly.
No DB password is written to SQL. AuthModule verifies legacy scrypt and upgrades
to bcrypt on successful login; the 18 approved seed credentials have been migrated.
Re-running INSERT seed preserves their bcrypt hashes and token versions.

`npm test` builds TypeScript and tests HTTP routes/modules using mocked
TypeORM repository; no `.env`, certificate or Aiven connection is required.
Passing tests does not prove that the production Aiven connection is configured.
# Giai đoạn 3

StaffShiftsModule và LeaveRequestsModule đã triển khai; xem
[PHASE3_TESTING.md](PHASE3_TESTING.md) để test API/seed/migration.
`npm test`: 11 tests pass; live Phase 2 và Phase 3 kiểm tra transaction/quyền pass.
Migration 005 đã áp dụng; seed ca giữ nguyên dữ liệu hiện có và có thể chạy lại.

## Giai đoạn 4 — Booking

AppointmentsModule có slots theo ca/nghỉ/cấu hình, booking transaction và
scope/state theo phiên. Xem [PHASE4_TESTING.md](PHASE4_TESTING.md).
Build +20 tests pass; live double booking201/409, đúng1 row; seed70 ca giữ nguyên.
`node test-phase4-live.cjs` chạy test fixture và cleanup;
`node test-phase4-live.cjs --verify-server` kiểm tra server cổng3000.

## Giai đoạn 5 — Reports

ReportsModule: 8 endpoints theo Manager/Boss/Staff, completed-only, UTC+7,
BIGINT string, read transaction và thống kê phái sinh. Không DDL/package mới.
Xem [PHASE5_TESTING.md](PHASE5_TESTING.md). Build+23 tests pass, live Aiven pass.
`node test-phase5-live.cjs` kiểm tra fixtures/cleanup;
`node test-phase5-live.cjs --verify-server` kiểm tra các API trên cổng3000.

