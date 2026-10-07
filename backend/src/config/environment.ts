export function validateEnvironment(values: Record<string, unknown>) {
  for (const key of ["DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD"]) {
    if (typeof values[key] !== "string" || !(values[key] as string).trim()) {
      throw new Error(`Missing required environment variable: ${key}`);
    }
  }
  const port = (key: string, fallback?: number) => {
    const raw = values[key] ?? fallback;
    if (!/^\d+$/.test(String(raw))) {
      throw new Error(`${key} must be an integer port`);
    }
    const value = Number(raw);
    if (value < 1 || value > 65535) {
      throw new Error(`${key} must be between 1 and 65535`);
    }
    return value;
  };
  if (typeof values.JWT_SECRET !== "string" || values.JWT_SECRET.length < 32)
    throw new Error("JWT_SECRET must be at least 32 characters");
  const ttl = Number(values.JWT_TTL_SECONDS ?? 1800);
  if (!Number.isInteger(ttl) || ttl < 60 || ttl > 3600)
    throw new Error("JWT_TTL_SECONDS must be 60..3600");
  return {
    ...values,
    DB_PORT: port("DB_PORT"),
    PORT: port("PORT", 3000),
    JWT_TTL_SECONDS: ttl,
  };
}
