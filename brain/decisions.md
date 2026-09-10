# Decision Log

## ADR-001: Modelo de autorizacion via RLS con helpers SECURITY DEFINER

**Status:** Accepted (2026-09-09)

**Context:** Supabase flageo 6 tablas (`profiles`, `athletes`, `invitations`, `invitation_tokens`, `trainer_subscriptions`, `supplement_logs`) con RLS deshabilitado — cualquiera con la anon key podia leer/escribir todo. La app no tiene backend propio: el cliente Flutter habla directo con PostgREST, asi que RLS es la unica capa de autorizacion.

**Decision:** Habilitar RLS en las 6 tablas con politicas por rol (`profiles.role`), usando funciones `SECURITY DEFINER` en schema `private` (`get_role()`, `my_trainer_id()`, `my_athlete_id()`) para evitar recursion en politicas de `profiles` y subconsultas por fila. `invitation_tokens` queda solo-admin. Migracion: `enable_rls_policies.sql`.

**Consequences:**
- Escalada de privilegios bloqueada (un usuario no puede auto-asignarse rol admin en insert/update de su perfil).
- El flujo first-login por token queda pendiente de migrar a Edge Function: ya estaba roto porque `admin_service.dart` llama `auth.admin.updateUserById`/`deleteUser` desde el cliente (requiere service key, 403 con anon key).
- Cualquier tabla nueva debe crearse con RLS habilitado + politicas desde el dia uno.
