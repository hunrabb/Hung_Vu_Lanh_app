# Customer booking, services and reviews

Implemented 12/10/2026.

- Home shows the upcoming appointment immediately below the greeting. Successful
  booking responses are retained while the appointment list reloads; a failed
  reload does not remove the new appointment or its cancellation action.
- Booking includes a month calendar with the current Hanoi date emphasized,
  past days disabled and a maximum booking horizon of one year. Existing server
  availability and conflict handling still determine whether a slot can be booked.
- Home categories, search, service links and hairstyle samples open the customer
  service catalog. Service details show the actual catalog price/duration, an
  illustrative category-specific process, offline hairstyle photos and a booking
  action that preselects the service and preserves the selected branch.
- Every existing seeded branch has a separate Manager account. Manager access is
  scoped by branch on the server; migration 006 enforces at most one Manager per
  branch. Boss retains chain-wide permissions.
- Customer completed appointment cards link to reviews. The customer may submit
  one branch review and one staff review per completed appointment, each with
  1–5 stars and an optional comment up to 1000 characters. Owner, role, status,
  target identity and duplicate checks are enforced on the server; a PostgreSQL
  trigger also verifies the appointment/target relationship. Staff reviews update
  the existing appointment rating used by staff reports. Public lists show actual
  counts/averages and paginated comments, with no fabricated star scores.

## API and database

- `POST /api/appointments/:id/reviews`: authenticated Customer only; JSON body
  `{ "target": "branch" | "staff", "rating": 1..5, "comment"?: "..." }`.
  The server derives customer and target IDs from the appointment, not the client.
- `GET /api/reviews?target=branch|staff&targetId=...&page=1`: public count, average
  and up to 20 reviews per page. Only reviewer display name and review content are
  public; no email, phone or credentials are returned.
- Migration: `database/006_reviews_and_branch_manager.sql`, after migrations
  001–005. Run `node migrate-customer-features.cjs` from `backend/`. It uses the
  existing `.env` configuration and TLS CA. Duplicate manager accounts abort the
  transaction; no account is removed automatically.
- Migration 006 was applied to the configured database in this session. The local
  backend was restarted and the new GET endpoint verified.

Mock reviews live in the app's repository in RAM and reset when the app restarts;
API reviews persist in PostgreSQL. The process descriptions and AI hairstyle
images are illustrative; prices and durations come from the actual catalog.

## Validation completed 13/10/2026

- Flutter: 130 tests passed; one opt-in live API test skipped. Static analysis
  with `flutter analyze --no-pub` passed.
- Backend: 27 tests passed. Public reviews GET was verified against the running
  local API. The database has no completed appointments, so the transactional
  live review insert check was skipped; posting guards are covered by unit tests.
- Nine UI previews at widths 320, 390 and 1280 cover service details, reviews and
  the month calendar without layout overflow.
