# Changelog

## 2026-09-14 — QA: Trainer weight registration + Student check-in history — PASSED

**What was tested:** RLS policies on body_progress (live DB via MCP), trainer service method surface, student service method surface, student dashboard navigation, new check-in history screen golden path and empty state, photo viewer.

**Issues found:**

### Issue 1 — Trainer cannot register/view student weight
- Root cause (DB): `body_progress` had no INSERT/UPDATE policy for trainers. The existing `body_progress_staff` policy was SELECT-only. `body_progress_own` (ALL) keyed on `private.my_athlete_id()` which returns NULL for a trainer session — so all trainer writes were silently rejected by RLS.
- Root cause (UI): `student_detail_screen.dart` rendered the weight section with `_SectionHeaderNoAction` (no action button). No dialog or service call existed to add a weight entry for a student.
- Fix (DB): Applied migration `body_progress_trainer_write` — new ALL policy for trainers scoped to `athlete_id IN (SELECT id FROM athletes WHERE trainer_id = my_trainer_id())`. Saved as `/body_progress_trainer_write.sql`.
- Fix (service): Added `logStudentWeight(String athleteId, double weight)` to `TrainerService` (`lib/services/trainer_service.dart`).
- Fix (UI): Changed the weight section header in `student_detail_screen.dart` from `_SectionHeaderNoAction` to `_SectionHeader(action: 'Agregar')`. Added `_showAddWeightDialog()` method with weight text field and SnackBar feedback. On save, calls `logStudentWeight` and invalidates `studentDetailProvider` to refresh the chart.

### Issue 2 — Students cannot see their own check-in history
- Root cause: No student-facing check-in history screen existed. The `check_ins` RLS already allowed students to read their own rows (`auth.uid() = user_id`). The service had `getLastCheckInDate()` and `getCheckInStatus()` but no "list all" method.
- Fix (service): Added `getMyCheckIns({int limit = 50})` to `StudentService` and `myCheckInsProvider` FutureProvider (`lib/services/student_service.dart`).
- Fix (UI): Created `lib/features/student/student_check_in_history_screen.dart` — card list with date, photo count badge, comment, horizontal photo strip (tap to fullscreen), and a fullscreen `_PhotoViewerScreen` with `InteractiveViewer` + `PageView`.
- Fix (navigation): Hooked the history screen into the student dashboard at two entry points: (1) the side drawer "Historial de Check-ins" item (replaced the "Mi Perfil" placeholder); (2) a "VER HISTORIAL" text link rendered directly under the CHECK-IN action button on the home tab (`lib/features/student/student_dashboard_screen.dart`).

**Status:** Passed — no compile errors introduced. All pre-existing warnings (withOpacity deprecations, unused elements) are unchanged from before. Sent to Xavier for approval.
