// Public GET target of Mercado Pago's OAuth redirect (verify_jwt = false).
// Trust comes from the signed, expiring `state` (binds the code to the trainer
// who started the flow). Redirects the browser back to the app either way.
import { verifyState } from "../_shared/crypto.ts";
import { connectTrainer } from "../_shared/mp_oauth.ts";

const back = (result: "connected" | "error") =>
  new Response(null, {
    status: 302,
    headers: {
      Location: `${Deno.env.get("APP_URL") ?? "https://prgs.app"}/trainer?mp=${result}`,
      "Cache-Control": "no-store",
    },
  });

Deno.serve(async (req) => {
  if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const trainerId = await verifyState(url.searchParams.get("state"));
  if (!code || code.length > 256 || !trainerId) return back("error");
  try {
    await connectTrainer(trainerId, code);
    return back("connected");
  } catch (e) {
    console.error("mp-oauth-callback failed", e instanceof Error ? e.message : "error");
    return back("error");
  }
});
