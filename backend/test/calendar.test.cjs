require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { plainToInstance } = require("class-transformer");
const { validate } = require("class-validator");
const { CreateLeaveDto } = require("../dist/leave-requests/leave.dto");
const { branchScope, interval } = require("../dist/common/calendar");
test("calendar scope rejects cross-branch managers and non-managers", () => {
  assert.throws(() => branchScope({ role: "manager", branchId: "A" }, "B"));
  assert.throws(() => branchScope({ role: "staff", branchId: "A" }, "A"));
  assert.doesNotThrow(() => branchScope({ role: "superAdmin" }, "B"));
});
test("calendar interval requires positive bounded duration", () => {
  assert.throws(() => interval("invalid", "invalid"));
  assert.throws(() => interval("2031-01-01T00:00Z", "2031-01-01T00:00Z"));
  assert.throws(() => interval("2031-01-01T00:00Z", "2031-03-01T00:00Z"));
  assert.equal(
    interval(
      "2031-01-01T08:00:00+07:00",
      "2031-01-01T09:00:00+07:00",
    ).startAt.toISOString(),
    "2031-01-01T01:00:00.000Z",
  );
});
test("leave DTO rejects timezone-free dates, blank reason and null", async () => {
  for (const startAt of [null, "2031-01-01", "2031-01-01T08:00:00"])
    assert.ok(
      (
        await validate(
          plainToInstance(CreateLeaveDto, {
            startAt,
            endAt: "2031-01-01T09:00:00Z",
            reason: "Medical",
          }),
        )
      ).length,
    );
  assert.ok(
    (
      await validate(
        plainToInstance(CreateLeaveDto, {
          startAt: "2031-01-01T08:00:00Z",
          endAt: "2031-01-01T09:00:00Z",
          reason: " ",
        }),
      )
    ).length,
  );
  assert.equal(
    (
      await validate(
        plainToInstance(CreateLeaveDto, {
          startAt: "2031-01-01T08:00:00Z",
          endAt: "2031-01-01T09:00:00Z",
          reason: "Medical",
        }),
      )
    ).length,
    0,
  );
});
