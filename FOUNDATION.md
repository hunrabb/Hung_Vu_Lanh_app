# Phase 1 foundation

The existing Flutter project is reused. No packages have been added.
The original TrangChu.dart, Noidung.dart, and PRD.md are preserved.

```text
lib/
|-- main.dart
|-- app.dart
|-- PRD.md
|-- TrangChu.dart                 (legacy, not wired into the new app)
|-- Noidung.dart                  (legacy, not wired into the new app)
|-- core/
|   |-- models/time_slot.dart
|   `-- routing/
|       |-- app_routes.dart
|       `-- app_router.dart
|-- shared/
|   `-- widgets/feature_placeholder.dart
`-- features/
    |-- auth/domain/app_user.dart
    |-- catalog/domain/service.dart
    |-- booking/domain/appointment.dart
    |-- schedule/domain/staff_shift.dart
    |-- admin/README.md
    `-- communication/domain/
        |-- conversation.dart
        `-- chat_message.dart
```

Add data/, application/, and presentation/ under each feature when its phase
needs repositories, controllers, and screens. Domain entities remain plain Dart.
Shared contains reusable widgets; core contains cross-feature infrastructure.

## Routing

Flutter's built-in Navigator handles named routes. Startup opens `/` (login).
AppRoutes.homeFor maps customer, staff, and admin to their landing routes.
All destinations are placeholders; unknown routes display a fallback page.
Actual sign-in, role guards, and redirect behavior belong to Phase 3. These
routes do not yet enforce permissions; backend authorization is also required.

## Entity conventions

- Users have customer, staff, or admin roles; passwords are not stored in models.
- Services have a category, duration, active flag, and integer minor-unit price.
  Default currency is VND, whose minor-unit amount is the whole dong amount.
- Appointments reference customer, staff, and service IDs. Their service list is
  immutable and total price is a booking-time snapshot.
- TimeSlot normalizes to UTC and rejects non-positive intervals. Display converts
  to local time. Half-open intervals allow adjacent bookings. This helper is not
  a complete booking engine: availability, shifts, and atomic conflict prevention
  are implemented later, with transaction enforcement in the eventual backend.
- StaffShift represents a dated work interval. Conversation and ChatMessage
  establish the entities for Phase 5.
- Admin reports will derive from appointment data in Phase 4.

## Next phase

Use Provider with ChangeNotifier for lightweight state management without code
generation. Install it in Phase 2 alongside in-memory repositories and mock data.
Do not add backend SDKs or generation tooling before they are needed.

## Verification

From ktgk/: run `flutter analyze --no-pub`, `flutter test --no-pub`, and
`flutter run` to launch the login placeholder. No production feature UI is built.
