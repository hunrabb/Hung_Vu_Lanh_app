import { BadRequestException } from "@nestjs/common";
import * as bcrypt from "bcrypt";
import { scrypt, timingSafeEqual } from "node:crypto";
export function validateNewPassword(value: string) {
  if (
    Buffer.byteLength(value, "utf8") > 72 ||
    value.includes("\0") ||
    !value.trim()
  )
    throw new BadRequestException(
      "Password must be nonblank and at most 72 UTF-8 bytes",
    );
}
export async function verifyPassword(
  value: string,
  hash: string,
): Promise<boolean> {
  if (/^\$2[aby]\$/.test(hash)) {
    if (Buffer.byteLength(value, "utf8") > 72 || value.includes("\0"))
      return false;
    return bcrypt.compare(value, hash);
  }
  const parts = hash.split("$");
  if (
    parts.length !== 7 ||
    parts[1] !== "scrypt" ||
    parts[2] !== "131072" ||
    parts[3] !== "8" ||
    parts[4] !== "1" ||
    !/^[a-f0-9]{32}$/.test(parts[5]) ||
    !/^[a-f0-9]{128}$/.test(parts[6])
  )
    return false;
  const actual = await new Promise<Buffer>((resolve, reject) =>
    scrypt(
      value,
      Buffer.from(parts[5], "hex"),
      64,
      { N: 131072, r: 8, p: 1, maxmem: 256 * 1024 * 1024 },
      (err, key) => (err ? reject(err) : resolve(key)),
    ),
  );
  return timingSafeEqual(actual, Buffer.from(parts[6], "hex"));
}
export const hashPassword = (value: string) => bcrypt.hash(value, 12);
