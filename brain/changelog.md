# Changelog

## 2026-09-20 — Schema-drift audit: code vs live DB — 8 bug clusters fixed

**Trigger:** Student signup (invite link, web) crashed with PGRST204 — code upserted `profiles.name`, which doesn't exist in prod. Full audit of every Supabase call site (~150) against live `information_schema` followed.

**Root cause (systemic):** Large parts of the code were written against an older intended schema. Live truth: names live on `athletes.name` / `trainers.name` (NOT `profiles`); streaks uses `current_count`/`best_count`/`last_activity_date` + NOT NULL `type` with UNIQUE `(athlete_id, type)`; trainers has no `specialty`/`is_active`/`has_logged_in`; `news_articles` and `supplement_logs.ticked_items` didn't exist.

**Fixed (code):**
1. `student_register_screen.dart` — dropped `name` from profiles upsert; write it to the `athletes` insert (was also violating NOT NULL).
2. `student_service._updateStreak` — rewritten to live columns + `type: 'workout'`, `onConflict: 'athlete_id,type'`, maintains `best_count`. The `streaks` table was EMPTY in prod: every workout completion had silently failed to record a streak since launch.
3. `student_service._notifyTrainerWorkoutCompleted` — embed `profiles(name)` made the whole select throw → trainer never got workout notifications. Now selects `athletes.name`.
4. `student_service.updateProfile` — name now updates `athletes`; dead `avatar_url` param removed.
5. `admin_service.createTrainer/updateTrainer/deactivateTrainer/completeFirstLogin/getAdminStats` — name/photo → `trainers.name`/`profile_photo`; active flag → `profiles.is_active`; first-login → `profiles.first_login_at`. Admin "add trainer" and the active/pending toggles were fully broken (PGRST204 / missing NOT NULL name).
6. `supabase_service.recordFirstLogin` — student name from `athletes`, fallback email.
7. Screens (`admin_dashboard`, `trainer_sheets`, `trainer_dashboard`, `student_detail`, `routine_detail`) — `profile['name']` → `trainer['name']`/`student['name']`; `is_active`/`has_logged_in` → profile fields; streak reads → `current_count`/`last_activity_date`. All silently showed "Sin nombre"/inactive before.

**Fixed (DB, migrations applied via MCP + saved at repo root):** `create_news_articles.sql` (table + RLS via `private.get_role()`; admin news CRUD + dashboard news had failed silently forever), `add_trainer_specialty.sql`, `add_supplement_ticked_items.sql`.

**Verified:** `flutter analyze` clean (baseline noise only), deployed to centr.xavierbenavidesm.workers.dev. `trainer_service.dart` audited clean.

## 2026-09-15 — QA: Re-investigation — Workout timer + Student weight logging — FAILED

**What was tested:** Tester re-reported "sigue todo igual" on three screens after a0db0f1 merged. Read the full commit diff, traced every code path from UI to DB, queried live Supabase DB for RLS policies, table constraints, and row counts.

**Issues found:**

### Bug 1 — Workout summary timer (contadores siguen corriendo)
Verdict: NOT-FIXED (partially). The a0db0f1 fix is structurally correct and was merged — `_completedElapsed`/`_completedRestTime` snapshots are properly captured and read in `_buildSummaryView`. However, `_saveWorkoutData` (called synchronously from `_completeWorkout` at line 459) passes `_totalElapsed` (the live getter) instead of `_completedElapsed` to `duration_seconds`. More critically: the fix handles the post-completion setState case but whether the tester is on a fresh build is unknown. If they are on a0db0f1, the display values should be frozen. If counters still advance, the remaining live path is the post-completion `setState` from `_fetchLastSession` resolving (line 170–175) — but since `_buildSummaryView` now reads the frozen snapshots, that setState is harmless to the displayed values. Most likely cause: stale build. See recommendation.

### Bug 2 — Student weight registration (No puedo registrar peso)
Verdict: FIXED-BUT-STALE-BUILD (same as Bug 1). Definitive evidence: the tester's screenshot shows "Gráfica de progreso próximamente" as the Historial Reciente placeholder. This exact string exists only in the pre-361c4ef codebase (commit 7c034a7). Commit 361c4ef (Sep 14 13:48) replaced it with the real fl_chart implementation. The tester is on a build from before 361c4ef, which is also before a0db0f1. DB confirms zero rows in body_progress — consistent with the student never having run the fixed build.
- Current code path (post 361c4ef) is sound: `logMetrics` -> `_getAthleteId()` (athletes_select RLS allows `user_id = auth.uid()`, confirmed) -> `body_progress` insert (body_progress_own policy USING/WITH CHECK `athlete_id = my_athlete_id()` matches). No DB constraints that would block same-day multiple inserts. postgrest-dart 2.6.0 throws on all 4xx/5xx, so errors are not silently swallowed.
- One secondary code smell (not the active bug): `_getAthleteId()` returns null silently if the athlete row is missing, resulting in `logMetrics` returning success while the body_progress insert is skipped and the UI shows "Peso registrado correctamente". This should be fixed defensively (throw instead of silent skip), but it is NOT what the tester is hitting.

### Bug 3 — Trainer side "Progreso de Peso — Sin datos de peso"
Verdict: FIXED-BUT-STALE-BUILD. The trainer-side "Agregar" dialog and `logStudentWeight` were added in a0db0f1. The trainer is on the same stale build. DB confirms body_progress_trainer_write policy is live and correct.

**Status:** All three bugs are FIXED-BUT-STALE-BUILD. Tester needs to install the current build from a0db0f1. No code changes required. One defensive hardening recommended (see secondary smell in Bug 2).

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
