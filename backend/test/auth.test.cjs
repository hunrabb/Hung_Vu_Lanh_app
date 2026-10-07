require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const {
  verifyPassword,
  hashPassword,
  validateNewPassword,
} = require("../dist/auth/passwords");
const { UsersService } = require("../dist/users/users.service");
test("bcrypt and existing scrypt seed verification, byte limit and invalid hashes", async () => {
  const hash = await hashPassword("Password123");
  assert.equal(await verifyPassword("Password123", hash), true);
  assert.equal(await verifyPassword("wrong", hash), false);
  const salt = crypto.randomBytes(16);
  const key = crypto.scryptSync("staff123", salt, 64, {
    N: 131072,
    r: 8,
    p: 1,
    maxmem: 256 * 1024 * 1024,
  });
  const legacy = [
    "$scrypt",
    "131072",
    "8",
    "1",
    salt.toString("hex"),
    key.toString("hex"),
  ].join("$");
  assert.equal(await verifyPassword("staff123", legacy), true);
  assert.equal(await verifyPassword("wrong", legacy), false);
  assert.equal(await verifyPassword("x", "$scrypt$corrupt"), false);
  assert.throws(() => validateNewPassword("é".repeat(37)));
  assert.throws(() => validateNewPassword("ab\0cd"));
});
test("UsersService enforces role and Branch without relying solely on controller guards", () => {
  const service = new UsersService({ find: async () => [] });
  assert.throws(
    () => service.findPendingStaff({ role: "manager", branchId: "a" }),
    { status: 403 },
  );
  assert.throws(
    () => service.findStaffByBranch("b", { role: "manager", branchId: "a" }),
    { status: 403 },
  );
  assert.throws(
    () => service.findStaffByBranch("a", { role: "staff", branchId: "a" }),
    { status: 403 },
  );
  assert.doesNotThrow(() =>
    service.findStaffByBranch("a", { role: "manager", branchId: "a" }),
  );
});
