import { assert, assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { decryptToken, encryptToken, signState, verifyState } from "./crypto.ts";

Deno.env.set("MP_TOKEN_ENC_KEY", btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))));
const TRAINER = "11111111-1111-4111-8111-111111111111";

Deno.test("token round-trips and ciphertext differs each time", async () => {
  const a = await encryptToken("APP_USR-secret");
  const b = await encryptToken("APP_USR-secret");
  assertNotEquals(a, b);
  assert(!a.includes("APP_USR"));
  assertEquals(await decryptToken(a), "APP_USR-secret");
});

Deno.test("tampered ciphertext is rejected", async () => {
  const [iv, ct] = (await encryptToken("x")).split(".");
  const flipped = ct.slice(0, -2) + (ct.endsWith("A") ? "B=" : "A=");
  let threw = false;
  try {
    await decryptToken(`${iv}.${flipped}`);
  } catch {
    threw = true;
  }
  assert(threw);
});

Deno.test("state verifies for its trainer, rejects forgery and expiry", async () => {
  const s = await signState(TRAINER);
  assertEquals(await verifyState(s), TRAINER);
  const [p, sig] = s.split(".");
  assertEquals(await verifyState(`${p}.${sig.replace(/.$/, sig.endsWith("0") ? "1" : "0")}`), null);
  assertEquals(await verifyState(`${btoa('{"t":"x","exp":9999999999}')}.${sig}`), null);
  assertEquals(await verifyState(await signState(TRAINER, -1)), null);
  assertEquals(await verifyState(null), null);
});
