# Decision Log

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
