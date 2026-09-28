# Decision Log

## 2026-09-27 — Client Changes: Supplements plain text + Check-in grid/compare

**Status:** Accepted

**Context:** Two Alan voice-note requests: (1) supplements should be plain informational text, not a daily checklist; (2) check-in photos should have an "Expandir" button showing a grid where the user can select two to compare.

**Decision:**

Item 1 — Supplements:
- Storage unchanged: `daily_supplements` + `chemical_supplements` text columns on `athletes` already existed and already hold free text. No migration needed.
- Student side: replaced `_SupplementChecklistModal` (a `ConsumerStatefulWidget` with `initState`/`_loadProgress`/`_toggleItem`/`_buildCheckItem` and a write path to `supplement_logs`) with a pure `_SupplementInfoModal` (a plain `StatelessWidget`). The modal shows the two text blocks in read-only containers with section headers. The `_showSupplementChecklist` helper renamed `_showSupplementInfo`; call site updated. `mySupplementsProvider` still used (read-only fetch). `getTodaySupplementLog`/`logSupplements` methods left in the service — the `supplement_logs` table may still be used for streaks; removing service methods would be a wider change with possible side-effects.
- Trainer side: `_showEditSupplementsDialog` and `updateAthleteSupplements` were already using multiline `TextField` — no change needed.

Item 2 — Check-in grid + select-to-compare:
- Added `CheckInGridSheet` (a `StatefulWidget`) to `check_in_comparison_screen.dart` alongside `CheckInComparisonScreen`. The sheet shows all check-ins in a 3-column `GridView`. Selection logic: first tap with no selection = open full-screen viewer; long-press or tap-while-selecting = select for compare. Selecting two activates an "Comparar fotos" button that pops the sheet and pushes `CheckInComparisonScreen` with the two chosen indices.
- Extended `CheckInComparisonScreen` with optional `initialLeft`/`initialRight` parameters so the grid can pre-load the chosen pair.
- Trainer `student_detail_screen.dart`: check-in section header changed from a conditional "Comparar" (only visible when ≥2 check-ins) to "Expandir" (visible when ≥1 check-in), which opens `CheckInGridSheet`. The old direct-push to `CheckInComparisonScreen` from the section header is replaced; compare is now reached through the grid.
- Student `student_check_in_history_screen.dart`: added an `IconButton` (grid icon) to the AppBar that opens `CheckInGridSheet` when check-ins are loaded. Student's check-in list shape matches the trainer's (`photo_urls`/`photo_url`/`assigned_date`/`created_at`).
- Added `cached_network_image` import to `check_in_comparison_screen.dart` (already a project dependency).

**Consequences:** `flutter analyze` clean (0 issues). No schema changes. On-device QA needed: (a) tap SUPLEMENTOS from student dashboard — should show read-only text, no checkboxes; (b) trainer opens student with check-ins → Expandir → grid appears, select two → Comparar → comparison screen with the right pair; (c) student → Mis Check-ins → grid icon in AppBar → same flow.

## 2026-09-26 — Bug Fix: Manual Register Exercise Order

**Status:** Accepted

**Context:** Client (Alan) reported that exercises in "Registro manual" appeared mirrored compared to the routine. The postgrest Dart client's `.order()` method defaults to `ascending: false` (descending). Both `getSessionExercises` and `getAthleteProgress` called `.order('order_index')` without the `ascending: true` parameter, so they returned exercises in reverse order. The student-facing paths (`WorkoutSessionScreen`, `StudentRoutineScreen`) compensate by doing a client-side `.sort()` ascending after receiving data from the Supabase nested join, so students never see the bug. The trainer's `SessionDetailScreen` does not re-sort — it renders the list as returned.

**Decision:** Added `ascending: true` to both `.order('order_index')` calls in `trainer_service.dart` (lines 1162 and 1262). Explicit is better than relying on a default.

**Consequences:** Manual register and progress chart exercise names now match the routine's displayed order. No schema changes needed. `flutter analyze` clean.

## 2026-09-26 — Alan QA Batch: Implementation complete

**Status:** Accepted

**Decision:** Full implementation of 8 bugs + 5 feature areas. `flutter analyze` clean (0 issues).

**Key architectural choices:**
- `check_in_photos` child table: `performCheckInFromUrls` now inserts photo rows after the parent insert; `getMyCheckIns` and `getStudentDetails` JOIN and normalise `photo_urls` from the child table. `CheckInPhotoViewerScreen` made public (renamed from `_PhotoViewerScreen`) so trainer gallery can reuse it.
- `set_logs`/`reps_logs` keying: no change needed — both student writer (`workout_session_screen`) and trainer reader (`session_detail_screen`) already key by integer list-position index. Bug 2 was assessed as a data-model question; the existing code is self-consistent (index = position in the `getSessionExercises` ORDER BY `order_index` result).
- `benefit_description` column: added to model, service `_columns`, create/update calls, admin form, and `BenefitsContent` card display.
- Instagram: normalised to full URL on save (`_normalizeInstagram`), displayed via new `instagramDisplayUrl` getter; admin form now accepts bare handle.
- Reorder: `ReorderableListView.builder` with `onReorderItem` (non-deprecated API); `reorderBrands` service method writes `display_order` per row.
- PRGS WhatsApp CTA: `AppConstants.prgsBrandsWhatsappUrl` placeholder constant, editable.
- `assigned_date`: `setCheckInAssignedDate` service method, long-press on gallery tile opens `showDatePicker`, shown in student history, comparison screen, and gallery overlay.
- Spacing bugs 7+8: removed orphan `SizedBox(height:24)` before optional consumers; spacing folded into card methods via `Padding(top:20)`.

**Issues flagged:** None — all items resolved.

**Open questions:** none.

---

## 2026-09-26 — Bug Investigation: Alan QA batch (7 bugs + 4 feature pointers)

**Status:** Accepted

**Decision:** Read-only investigation completed. All 7 bugs have exact file:line attribution and a root-cause hypothesis. 4 feature pointer locations identified. No code changes made.

**Issues flagged:** See full report in conversation output above (2026-09-26 Alex QA investigation).

## 2026-09-25 — Bug Fixes: Brand logo upload, admin exercise search & edit/delete

**Status:** Accepted

**Context:** Three admin-app issues reported by client: (1) brand logo gallery upload button does nothing, (2) admin exercise list has no search, (3) admin cannot edit or delete exercises.

**Issue 1 — Brand logo upload root cause:**
The Dart code in `_BrandSheetState._pickLogo()` (admin_dashboard_screen.dart) is logically correct: `readAsBytes()` + `uploadBrandLogoBytes()` + `setState(() => _logoController.text = url)`. The runtime failure is a **Supabase Storage policy gap**: the `exercise-media` bucket had no INSERT/UPDATE policy for `role='admin'`, so every upload attempt threw a 403 and the catch block reset state silently. Fix: SQL migration `add_admin_exercise_edit_delete.sql` adds `admin upload exercise-media` and `admin update exercise-media` storage policies, and ensures the bucket is public.

**Issue 2 — Admin exercise search:**
`AdminExercisesView` was a `ConsumerWidget` with no local state. Fix: converted to `ConsumerStatefulWidget`, added a `TextField` with `_searchQuery` state, filtered using the shared `foldSearch()` helper from `core/utils/string_utils.dart` (same pattern as trainer exercise search and editor search box).

**Issue 3 — Admin exercise edit/delete:**
The existing `add_admin_exercise_rls.sql` trigger `exercises_admin_global_addonly` raised an exception if an admin tried to update any field other than `is_hidden`. No DELETE policy existed. Fix: SQL migration updates the trigger to allow admin full-field edits on global exercises; adds `exercises_admin_delete` policy; adds `updateGlobalExercise()` and `deleteGlobalExercise()` methods to `AdminService`; replaces the `_CreateExerciseSheet` in `admin_exercises_screen.dart` with a self-contained `_AdminExerciseSheet` that uses both methods; adds edit and delete actions to the per-row `PopupMenuButton`.

**Consequences:** All three `flutter analyze` checks pass clean. SQL migration must be applied to the live Supabase project. The trainer `_CreateExerciseSheet` is deliberately NOT reused for admin edits because it calls `trainerServiceProvider` (wrong service) and was blocked by the trigger anyway.

---

## 2026-09-21 — Bug Fix: TypeError on exercise list in Agregar Ejercicio sheet

**Status:** Accepted

**Context:** Trainer "Agregar Ejercicio" bottom sheet threw a red error widget on every seed row after the first trainer row rendered fine. Error: `type 'List<dynamic>' is not a subtype of type 'String?'`. The seed import from PRGS xlsx stored `equipment` as a `text[]` Postgres array; trainer rows had `null`.

**Root cause:** `ExerciseModel.fromMap` cast `map['equipment']` as `String?`. For seed rows with `["Barra"]` etc. the runtime cast from `List<dynamic>` to `String?` throws immediately. The live DB schema confirms `equipment` column is `ARRAY` (`_text`/`text[]`), not `text`.

**Decision:** Changed `equipment` field in `ExerciseModel` from `String?` to `List<String>` (default `const []`). Updated `fromMap` to use the existing `asList()` helper: `equipment: asList(map['equipment'] ?? i18n['equipment'])`. Updated the one display callsite in `exercise_detail_screen.dart` to iterate the list: `ex.equipment.map(_translateEquipment).join(' / ')`. No migration needed — column type was already correct in prod; the model was wrong.

**Consequences:** All rows (seed and trainer) parse without throwing. `exercise_detail_screen` renders a joined string for multi-item equipment lists. `toMap` already wrote the list correctly. `flutter analyze` clean. Layout change from earlier session (keyboard inset fix) is unrelated and correct — kept as-is.

## 2026-09-21 — Bug Fix: Add Exercise sheet grey box / no results on typing

**Status:** Accepted

**Context:** Client reported that typing in the "Buscar Ejercicio" search field in the Add Exercise sheet showed a big empty grey box with no results. Reproduced path: trainer opens routine → taps "Agregar Ejercicio" → types "na" → exercise list area appears empty.

**Investigation:** RLS verified correct (168 rows visible to authenticated trainer). Dart filter logic confirmed correct via isolated repro script — `contains('na')` matches 20+ Spanish exercise names. DB query as authenticated role returns all expected rows. No autoDispose providers. No parsing errors in `ExerciseModel.fromMap`.

**Root cause:** Layout bug in `_AddExerciseSheetState.build()`. The outer `Container(height: 90% of screen)` applied `padding: EdgeInsets.only(bottom: viewInsets.bottom)`. When the user taps the search `TextField` and the keyboard opens (~346px on iOS, ~300–380px on Android), this padding squeezes the `Expanded` viewport inside the Column. On small phones (740px logical height), the `Container(height: 220)` holding the exercise list is pushed partially or fully below the visible area of the `SingleChildScrollView`. The user sees nothing where results should be — they would have to scroll down past the keyboard to find them, but the UX gives no indication of this.

**Decision:** Remove `viewInsets.bottom` from the outer Container padding. Instead add a `SizedBox(height: keyboardHeight)` at the bottom of the scrollable Column content. This keeps the `Expanded` viewport at full size while still allowing the `SingleChildScrollView` to scroll to reveal content that would otherwise sit behind the keyboard.

**Consequences:** The exercise list stays visible when the keyboard opens on all tested phone sizes. The search bar and filter chips remain accessible. One-line diff per concern, `flutter analyze` clean.

## 2026-09-20 — QA: Exercise Library (Global Catalog + Copy-on-Edit) — NEEDS FIXES ❌

**Decision:** Feature is structurally sound and the RLS is solid, but two real bugs block approval: (1) the edit/copy button is live while `myTrainerIdProvider` is still loading, causing an accidental duplicate of an owned exercise on a fast tap (WARNING severity); (2) clearing the YouTube URL field during a duplicate-creation does not clear `video_url` in the DB because `createExercise` already persisted it before the form is submitted (Bug severity). Both are fixable with small targeted changes.

**Issues flagged:**
- Bug: Clearing YouTube URL during duplicate doesn't clear `video_url` — `createExercise` stores the source URL before the user's form choices are applied. (`exercise_library_screen.dart:1143–1213`)
- Warning: Race condition on edit/copy button — while `myTrainerIdProvider` is loading (`valueOrNull = null`), all exercises show as not-owned, so the button is live and shows the copy icon; a fast tap on an owned exercise creates an unwanted duplicate. (`exercise_library_screen.dart:516–577`)

**Open questions:** None — both bugs have clear fixes documented in the QA report.

**Resolution (2026-09-21):** Both fixed. Edit/copy button now disabled while `myTrainerIdProvider` is loading; video/images resolved from final form state (not passed to `createExercise`) so a cleared field clears. `flutter analyze` clean. Feature approved.

## 2026-09-14 — Plan Review: APPROVED (QA fixes, no plan to review)

**Decision:** Two targeted bug fixes applied directly (no plan phase needed — both are well-scoped incremental changes to existing patterns).

**Issues flagged:** See changelog entry 2026-09-14 for full root cause analysis.

**Open questions:** None — both fixes are self-contained and verified clean against the live DB and flutter analyze.

## 2026-09-14 — Bug Fix: Workout summary timer advancing after completion

**Status:** Accepted

**Context:** After febcecb introduced `_backgroundTime` (a mutable `Duration` accumulator) and replaced `_totalStopwatch.elapsed` with the live getter `_totalElapsed = _totalStopwatch.elapsed + _backgroundTime` throughout the screen, the "¡Entrenamiento Completado!" summary card showed advancing numbers. Tester observed Tiempo Total ≠ Ejercicio + Descansos (1-second gap), consistent with the total still ticking after completion.

**Root cause (three layered issues):**
1. `_buildSummaryView` read `_totalElapsed` — a live computed getter — on every rebuild. While `_totalStopwatch` IS stopped by `_completeWorkout()`, any `setState` call after completion (e.g. from `_fetchLastSession` completing) caused a rebuild that re-evaluated the getter. Pre-febcecb, `_totalStopwatch.elapsed` on a stopped stopwatch returned a frozen value — safe. But with `_backgroundTime` added, any background→foreground lifecycle transition while on the summary screen could (theoretically) increment `_backgroundTime` if not guarded, and trigger another `setState`.
2. `didChangeAppLifecycleState` had no `_isCompleted` guard: it would set `_backgroundEnterTime` and on `resumed` enter the resume branch. The `_totalStopwatch.isRunning` check at line 138 blocked `_backgroundTime` accumulation, but the code still ran unnecessarily.
3. `_completeWorkout()` was called INSIDE a `setState()` callback in `_endRest()`, creating a setState-within-setState pattern; timer cancellation happened synchronously but the values read by `_buildSummaryView` could differ across nested build cycles.

**Decision:** Snapshot `_totalElapsed` and `_totalRestTime` into `_completedElapsed` and `_completedRestTime` fields at the top of `_completeWorkout()`, before any `cancel()`/`stop()` calls. `_buildSummaryView` reads these frozen values (with `??` fallback to the live getter for safety). Add `if (_isCompleted) return;` guard at the top of `didChangeAppLifecycleState`. No changes to the febcecb background-time logic for active workouts.

**Consequences:**
- Summary card stats are fully frozen at the exact moment of completion — no further setState triggers can change them.
- The background-freeze fix from febcecb (crediting OS-suspended time during active workout) is fully preserved.
- `_saveWorkoutData` continues to read `_totalElapsed` which at call time equals `frozenTotal` (stopwatch stopped, backgroundTime frozen).
- File changed: `lib/features/student/workout_session_screen.dart`

## ADR-001: Modelo de autorizacion via RLS con helpers SECURITY DEFINER

**Status:** Accepted (2026-09-09)

**Context:** Supabase flageo 6 tablas (`profiles`, `athletes`, `invitations`, `invitation_tokens`, `trainer_subscriptions`, `supplement_logs`) con RLS deshabilitado — cualquiera con la anon key podia leer/escribir todo. La app no tiene backend propio: el cliente Flutter habla directo con PostgREST, asi que RLS es la unica capa de autorizacion.

**Decision:** Habilitar RLS en las 6 tablas con politicas por rol (`profiles.role`), usando funciones `SECURITY DEFINER` en schema `private` (`get_role()`, `my_trainer_id()`, `my_athlete_id()`) para evitar recursion en politicas de `profiles` y subconsultas por fila. `invitation_tokens` queda solo-admin. Migracion: `enable_rls_policies.sql`.

**Consequences:**
- Escalada de privilegios bloqueada (un usuario no puede auto-asignarse rol admin en insert/update de su perfil).
- El flujo first-login por token queda pendiente de migrar a Edge Function: ya estaba roto porque `admin_service.dart` llama `auth.admin.updateUserById`/`deleteUser` desde el cliente (requiere service key, 403 con anon key).
- Cualquier tabla nueva debe crearse con RLS habilitado + politicas desde el dia uno.

## 2026-09-24 — Plan Review: QA Batch — APPROVED ✅

**Decision:** All seven client-requested features in this batch are approved. One Nit-level code smell and one Warning-level logic fragility are documented below but do not block the commit.

**Issues flagged:**

- Nit: `student_dashboard_screen.dart:619` — the `reading!.accepted` null-bang is theoretically safe (the `content == null` short-circuit on line 617 guarantees `reading` is non-null by the time `!` fires, because `content` is derived from `reading?.content`), but it is needlessly surprising. A cleaner expression is `(reading?.accepted ?? false)` which is self-documenting and avoids the bang entirely.
- Warning: `student_history_screen.dart` — `_exerciseChart` builds `bars` from its own locally-recomputed `sortedSets`; `_setSelector` uses `_seriesOf()` which also recomputes from `_recent(points)`. Both are pure functions of the same `points` list so they are always consistent. However `_selectedSet` is validated against the chart-local `sortedSets` (not the chip list's series) at line 562, so a stale `_selectedSet` from a previous exercise silently falls back to "all series" — this is the correct and safe behavior, but there is no visual feedback to the user that their selection was reset. Acceptable for now.
- No issues: required_reading_accepted_at RLS is covered by the existing `athletes_update` policy (`user_id = auth.uid()`), which correctly scopes the student to their own row only. The `acceptRequiredReading()` method filters by `user_id` — row ownership is correctly enforced at both the app layer and the DB layer.
- No issues: `trainerRequiredReadingProvider` record-type refactor — all three consumers (required_reading_screen, student_dashboard home banner, student_dashboard drawer) correctly access `.content` and `.accepted`. No dangling old `String?` usage found.
- No issues: `BenefitsContent` extraction is clean — `_BenefitsContent` fully removed from student_dashboard, unused imports (`url_launcher`, `affiliated_brand_service`, `affiliated_brand_model`) removed, `BenefitsContent` imported from widgets. TrainerBenefitsScreen wraps correctly.
- No issues: Check-in comparison screen handles legacy `photo_url` / new `photo_urls` array correctly, with empty-state guard and full-screen interactive viewer. Entry point gated on `checkIns.length >= 2`.
- No credentials found in any changed file.

**Open questions sent back to Marco:** None.

## 2026-09-27 — Alan QA Batch #2 (WhatsApp feedback, 25–27/09) — SHIPPED

Read the client WhatsApp thread (Arc + WhatsApp Web DOM extraction) from 25/09 6:22pm → 27/09. 8 bugs + 11 features + 3 voice-note items. `flutter analyze` clean. 5 additive migrations applied to live Supabase and saved at repo root.

### ADR-002: Trainer write-access to workout_logs & check_ins via additive RLS
**Status:** Accepted (2026-09-27)
**Context:** "Registrar en persona" (trainer logs an in-person session) silently failed — `workout_logs_own` (ALL) gated on `athlete_id = private.my_athlete_id()`, which is NULL for trainers, so every trainer INSERT was dropped by RLS. Same shape blocked trainers setting a manual check-in date.
**Decision:** Add scoped trainer policies (INSERT/UPDATE) gated on `athlete_id/user_id ∈ (athletes WHERE trainer_id = private.my_trainer_id()) OR get_role()='admin'`. Files: `add_workout_logs_trainer_insert.sql`, `add_check_in_assigned_date.sql` (+ `assigned_date date` col), `add_notifications_delete_policy.sql` (owner DELETE), `add_check_in_photos_multi_support.sql` (trainer SELECT on check_in_photos + athlete storage UPDATE), `add_affiliated_brands_benefit.sql` (`benefit_description` col; `display_order` already existed).
**Consequences:** Trainers can log/correct sessions and assign check-in dates for their own athletes only. Security advisor: no new issues. Client now writes/reads multi-photo check-ins via the canonical `check_in_photos` table (was saving only `check_ins.photo_url`).

### ADR-003: postgrest-dart `.order()` defaults to DESCENDING
**Status:** Accepted (2026-09-27)
**Context:** "ejercicios espejados a la rutina" — manual-register exercise list showed reversed order. Root cause: `.order('order_index')` without `ascending:` returns rows DESC in postgrest-dart; student screens were unaffected because they client-side `.sort()`, but `SessionDetailScreen` used the list raw.
**Decision:** Always pass `ascending: true` explicitly on order-sensitive queries. Fixed `getSessionExercises` + `getAthleteProgress` (trainer_service.dart).
**Consequences:** Reusable lesson — never rely on the default sort direction in postgrest-dart.

### Decisions taken (Xavier said "fix everything")
- Supplements: **removed the daily checkbox** → plain read-only multiline text (data already in `athletes.daily_supplements`/`chemical_supplements`; no migration). Reverses the earlier "keep checkbox" call per Alan's voice note.
- PRGS brands CTA number = editable const `prgsBrandsWhatsappUrl` placeholder (TODO real number).
- Brand "Beneficio" = new `benefit_description` column.
- All user-facing "CENTR" wordmark/strings → **PRGS** (login, admin app-bar, invite email, footer). External display name left as "Progress" (Android/iOS/web).

### Pending (need Xavier)
- Real PRGS WhatsApp number.
- Skip-exercise reorder: skip currently sends exercise to END; Alan leans toward skip→NEXT position but is confirming with designer + another trainer. NOT built.
