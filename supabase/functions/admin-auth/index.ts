// Privileged auth operations that the Flutter client cannot perform with the
// anon key. Three actions:
//   create_trainer        (admin JWT required)  — creates confirmed auth user
//   delete_user           (admin JWT required)  — deletes a non-admin auth user
//   complete_first_login  (invitation token is the credential, pre-auth)
import { createClient } from "npm:@supabase/supabase-js@2";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { action, ...params } = await req.json();

    const getCaller = async () => {
      const jwt = (req.headers.get("Authorization") ?? "").replace(
        "Bearer ",
        "",
      );
      const { data: { user }, error } = await admin.auth.getUser(jwt);
      if (error || !user) throw new Error("No autorizado");
      const { data: profile } = await admin
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .single();
      return { user, role: profile?.role as string | undefined };
    };

    const requireAdmin = async () => {
      const { role } = await getCaller();
      if (role !== "admin") throw new Error("No autorizado");
    };

    if (action === "create_trainer") {
      await requireAdmin();
      const { email, name } = params;
      if (!email || !name) throw new Error("email y name son requeridos");
      const tempPassword = crypto.randomUUID().replace(/-/g, "").slice(0, 12) +
        "A1!";
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: tempPassword,
        email_confirm: true,
        user_metadata: { full_name: name, role: "trainer" },
      });
      if (error) throw error;
      return json({ user_id: data.user.id, temp_password: tempPassword });
    }

    if (action === "delete_user") {
      await requireAdmin();
      const { user_id } = params;
      if (!user_id) throw new Error("user_id es requerido");
      const { data: target } = await admin
        .from("profiles")
        .select("role")
        .eq("id", user_id)
        .single();
      if (target?.role === "admin") {
        throw new Error("No se puede eliminar un admin");
      }
      const { error } = await admin.auth.admin.deleteUser(user_id);
      if (error) throw error;
      return json({ ok: true });
    }

    // Delete one of the caller's own students (or any, if the caller is admin).
    // Cascade FKs remove the profile + athlete rows once the auth user is gone.
    if (action === "delete_student") {
      const { athlete_id } = params;
      if (!athlete_id) throw new Error("athlete_id es requerido");
      const caller = await getCaller();

      const { data: athlete } = await admin
        .from("athletes")
        .select("id, user_id, trainer_id")
        .eq("id", athlete_id)
        .maybeSingle();
      if (!athlete) throw new Error("Alumno no encontrado");

      if (caller.role !== "admin") {
        const { data: trainer } = await admin
          .from("trainers")
          .select("id")
          .eq("user_id", caller.user.id)
          .maybeSingle();
        if (!trainer || trainer.id !== athlete.trainer_id) {
          throw new Error("No autorizado");
        }
      }

      if (athlete.user_id) {
        // Deleting the auth user cascades to profiles → athletes.
        const { error } = await admin.auth.admin.deleteUser(athlete.user_id);
        if (error) throw error;
      } else {
        // Half-created athlete with no auth account: drop the row directly.
        const { error } = await admin
          .from("athletes")
          .delete()
          .eq("id", athlete_id);
        if (error) throw error;
      }
      return json({ ok: true });
    }

    if (action === "complete_first_login") {
      const { token, new_password } = params;
      if (typeof token !== "string" || token.length < 8) {
        throw new Error("Token inválido");
      }
      if (typeof new_password !== "string" || new_password.length < 6) {
        throw new Error("La contraseña debe tener al menos 6 caracteres");
      }
      const { data: tokenData } = await admin
        .from("invitation_tokens")
        .select("user_id, expires_at")
        .eq("token", token)
        .eq("is_used", false)
        .maybeSingle();
      if (!tokenData) throw new Error("Token inválido o expirado");
      if (new Date() > new Date(tokenData.expires_at)) {
        throw new Error("Token expirado");
      }
      const { error } = await admin.auth.admin.updateUserById(
        tokenData.user_id,
        { password: new_password },
      );
      if (error) throw error;
      await admin
        .from("profiles")
        .update({ first_login_at: new Date().toISOString() })
        .eq("id", tokenData.user_id);
      await admin
        .from("invitation_tokens")
        .update({ is_used: true })
        .eq("token", token);
      return json({ ok: true });
    }

    throw new Error("Acción desconocida");
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
