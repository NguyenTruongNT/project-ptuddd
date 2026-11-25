// No third-party imports. JWT is verified with Auth before using any service key.
const base = Deno.env.get("SUPABASE_URL")!;
const publicKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function response(status: number, value: unknown) {
  return new Response(JSON.stringify(value), {
    status, headers: { ...cors, "Content-Type": "application/json" },
  });
}
function validImage(b: Uint8Array, mime: string): boolean {
  const view = new DataView(b.buffer, b.byteOffset, b.byteLength);
  const within = (w: number, h: number) => w > 0 && h > 0 && w * h <= 40_000_000;
  if (mime === "image/png") {
    return b.length >= 45 &&
      [137, 80, 78, 71, 13, 10, 26, 10].every((v, i) => b[i] === v) &&
      view.getUint32(8) === 13 && view.getUint32(12) === 0x49484452 &&
      within(view.getUint32(16), view.getUint32(20)) &&
      view.getUint32(b.length - 8) === 0x49454e44;
  }
  if (mime === "image/jpeg") {
    if (b.length < 12 || b[0] !== 255 || b[1] !== 216 ||
      b[b.length - 2] !== 255 || b[b.length - 1] !== 217) return false;
    let pos = 2;
    while (pos + 4 < b.length) {
      if (b[pos++] !== 255) return false;
      while (b[pos] === 255) pos++;
      const marker = b[pos++];
      if (marker === 0xda || marker === 0xd9) return false;
      if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (pos + 2 > b.length) return false;
      const length = view.getUint16(pos);
      if (length < 2 || pos + length > b.length) return false;
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7,
        0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
        return length >= 8 && within(view.getUint16(pos + 5), view.getUint16(pos + 3));
      }
      pos += length;
    }
    return false;
  }
  if (mime === "image/webp") {
    if (b.length < 25 || view.getUint32(0) !== 0x52494646 ||
      view.getUint32(8) !== 0x57454250 || view.getUint32(4, true) + 8 !== b.length) return false;
    const kind = view.getUint32(12);
    if (kind === 0x56503858) {
      if(b.length<30)return false;
      const w = 1 + b[24] + (b[25] << 8) + (b[26] << 16);
      const h = 1 + b[27] + (b[28] << 8) + (b[29] << 16);
      return within(w, h);
    }
    if (kind === 0x56503820) {
      if(b.length<30)return false;
      return b[23] === 0x9d && b[24] === 0x01 && b[25] === 0x2a &&
        within(view.getUint16(26, true) & 0x3fff, view.getUint16(28, true) & 0x3fff);
    }
    if (kind === 0x5650384c && b[20] === 0x2f) {
      const bits = view.getUint32(21, true);
      return within((bits & 0x3fff) + 1, ((bits >>> 14) & 0x3fff) + 1);
    }
  }
  return false;
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return response(405, { code: "INVALID_INPUT" });
  try {
    const auth = req.headers.get("Authorization") ?? "";
    if (!auth.startsWith("Bearer ")) return response(401, { code: "AUTH_REQUIRED" });
    const headers = { apikey: publicKey, Authorization: auth, "Content-Type": "application/json" };
    const who = await fetch(base + "/auth/v1/user", { headers });
    if (!who.ok) return response(401, { code: "AUTH_REQUIRED" });
    const user = await who.json();
    const body = await req.json();
    if (!/^[0-9a-f-]{36}$/i.test(body.image_id ?? "")) {
      return response(400, { code: "INVALID_INPUT" });
    }
    const reservation = await fetch(base + "/rest/v1/rpc/get_my_material_upload", {
      method: "POST", headers, body: JSON.stringify({ p_image_id: body.image_id }),
    });
    if (!reservation.ok) return response(403, { code: "FORBIDDEN" });
    const upload = await reservation.json();
    if (!upload) return response(403, { code: "FORBIDDEN" });
    const file = await fetch(base + "/storage/v1/object/authenticated/studyshare-material-images/" +
      upload.storage_path, { headers });
    if (!file.ok) return response(400, { code: "EVIDENCE_UPLOAD_FAILED" });
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length !== upload.byte_size || bytes.length > 5242880 ||
      !validImage(bytes, upload.mime_type)) {
      return response(400, { code: "INVALID_INPUT" });
    }
    const verified = await fetch(base + "/rest/v1/rpc/verify_material_image_upload", {
      method: "POST",
      headers: { apikey: serviceKey, Authorization: "Bearer " + serviceKey,
        "Content-Type": "application/json" },
      body: JSON.stringify({ p_image_id: upload.id, p_actor_id: user.id }),
    });
    if (!verified.ok) return response(409, { code: "CONFLICT" });
    return response(200, { ok: true, image_id: upload.id });
  } catch {
    return response(400, { code: "INVALID_INPUT" });
  }
});
