# Project context for future code changes

Read `PROJECT_CONTEXT.md` and `lib/PRD.md` before changing this project. Re-read
the affected source files and relevant tests; the context document is a snapshot,
not a substitute for current code. Update it when architecture or behavior changes.

Keep the PRD's lightweight, feature-first Flutter architecture. Use the existing
Provider/ChangeNotifier and named Navigator routes. Add dependencies only when
the requested feature needs them. Preserve existing UI and behavior outside the
requested scope. Domain models are plain Dart.

Work in `ktgk/`; the sibling `learn_flutter/` is a separate project.
Keep session and role guards, logout history clearing, cancellation after
sign-out/dispose, integer money, UTC intervals, and immutable service ID lists.
Do not mistake preview SnackBars or screen-local mock state for implemented
repositories or backend features. Read the tests before changing these contracts.

For Dart changes, run appropriate existing tests and `flutter analyze --no-pub`
from this directory. SDK on this machine: `C:\flutter\bin\flutter.bat`.
Do not edit generated build/cache/platform registration files.
