require("reflect-metadata");
const { test } = require("node:test"),
  assert = require("node:assert/strict");
const { reportRange, reportPeriods } = require("../dist/reports/report-period");
const { ReportsService } = require("../dist/reports/reports.service");
const { ReportQueryDto } = require("../dist/reports/report.dto");
const { plainToInstance } = require("class-transformer"),
  { validate } = require("class-validator");
test("report dates use Hanoi inclusive calendar dates, UTC half-open bounds and leap months", () => {
  const range = reportRange({ from: "2026-10-07", to: "2026-10-07" });
  assert.equal(range.from.toISOString(), "2026-10-06T17:00:00.000Z");
  assert.equal(range.to.toISOString(), "2026-10-07T17:00:00.000Z");
  const periods = reportPeriods(Date.parse("2024-02-29T18:00:00Z"));
  assert.equal(periods.month.from.toISOString(), "2024-02-29T17:00:00.000Z");
  assert.equal(periods.month.to.toISOString(), "2024-03-31T17:00:00.000Z");
  assert.throws(() => reportRange({ from: "2026-02-30", to: "2026-03-01" }));
  assert.throws(() => reportRange({ from: "2026-10-07" }));
  assert.throws(() => reportRange({ from: "2026-10-08", to: "2026-10-07" }));
  assert.throws(() => reportRange({ from: "2025-01-01", to: "2026-12-31" }));
});
test("report services enforce roles and required branch before touching DB", () => {
  const service = new ReportsService({});
  assert.throws(() => service.dashboard({ role: "staff", branchId: "A" }));
  assert.throws(() =>
    service.dashboard({ role: "manager", branchId: "A" }, true),
  );
  assert.throws(() => service.earnings({ role: "customer" }, {}));
  assert.throws(() => service.revenue({ role: "manager", branchId: null }, {}));
});
test("Manager/Staff query DTO rejects scope injection and invalid pagination", async () => {
  for (const payload of [
    { branchId: "B" },
    { staffId: "other" },
    { limit: 101 },
    { page: null },
  ])
    assert.ok(
      (
        await validate(plainToInstance(ReportQueryDto, payload), {
          whitelist: true,
          forbidNonWhitelisted: true,
        })
      ).length,
    );
  assert.equal(
    (
      await validate(
        plainToInstance(ReportQueryDto, {
          from: "2026-10-07",
          to: "2026-10-08",
        }),
      )
    ).length,
    0,
  );
});
