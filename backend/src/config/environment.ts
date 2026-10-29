export function validateEnvironment(values: Record<string, unknown>) {
  for (const key of ["FIREBASE_PROJECT_ID", "FIRESTORE_DATABASE_ID"]) {
    if (typeof values[key] !== "string" || !(values[key] as string).trim())
      throw new Error("Missing required environment variable: " + key);
  }
  if (typeof values.JWT_SECRET !== "string" || values.JWT_SECRET.length < 32)
    throw new Error("JWT_SECRET must be at least 32 characters");
  const ttl = Number(values.JWT_TTL_SECONDS ?? 1800),
    port = Number(values.PORT ?? 3000);
  if (!Number.isInteger(ttl) || ttl < 60 || ttl > 3600)
    throw new Error("JWT_TTL_SECONDS must be 60..3600");
  if (
    !/^\d+$/.test(String(values.PORT ?? 3000)) ||
    !Number.isInteger(port) ||
    port < 1 ||
    port > 65535
  )
    throw new Error("PORT must be an integer port 1..65535");
  return { ...values, PORT: port, JWT_TTL_SECONDS: ttl };
}
