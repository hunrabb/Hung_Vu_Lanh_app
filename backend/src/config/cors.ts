/** Explicit browser origins when configured; local development stays compatible. */
export function corsOrigin(value: unknown): true | string[] {
  if (value === undefined || value === "") return true;
  if (typeof value !== "string") throw new Error("CORS_ORIGINS must be a comma-separated list");
  const origins = value.split(",").map((origin) => origin.trim()).filter(Boolean);
  if (!origins.length) throw new Error("CORS_ORIGINS must contain an origin");
  for (const origin of origins) {
    let parsed: URL;
    try { parsed = new URL(origin); } catch { throw new Error("Invalid CORS_ORIGINS origin"); }
    if (!["http:", "https:"].includes(parsed.protocol) || parsed.origin !== origin) {
      throw new Error("CORS_ORIGINS entries must be HTTP(S) origins without paths");
    }
  }
  return [...new Set(origins)];
}
