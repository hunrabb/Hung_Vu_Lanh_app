require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { NestFactory } = require("@nestjs/core");
const { ValidationPipe } = require("@nestjs/common");
const { DataSource } = require("typeorm");
const { AppModule } = require("./dist/app.module");
(async () => {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix("api");
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  const db = app.get(DataSource),
    shifts = [],
    leaves = [];
  if (process.argv.includes("--verify-server")) {
    try {
      const login = await fetch("http://localhost:3000/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: "admin@example.com",
          password: "admin123",
        }),
      });
      assert.equal(login.status, 200);
      const auth = await login.json();
      const response = await fetch(
        "http://localhost:3000/api/branches/branch-01/shifts",
        { headers: { Authorization: "Bearer " + auth.accessToken } },
      );
      assert.equal(response.status, 200);
      console.log(
        JSON.stringify({
          server: "localhost:3000",
          status: response.status,
          branch01Shifts: (await response.json()).length,
        }),
      );
      const [{ count }] = await db.query(
        "SELECT count(*)::int AS count FROM staff_leave_requests WHERE reason='Phase3 temporary medical leave'",
      );
      assert.equal(count, 0);
    } finally {
      await app.close();
    }
    return;
  }
  if (process.argv.includes("--recover-test-data")) {
    try {
      await db.transaction(async (m) => {
        const rows = await m.query(
          "SELECT id FROM appointments WHERE id LIKE 'phase3-%' AND customer_name='Phase3 test'",
        );
        for (const row of rows) {
          await m.query(
            "DELETE FROM appointment_services WHERE appointment_id=$1",
            [row.id],
          );
          await m.query("DELETE FROM appointments WHERE id=$1", [row.id]);
        }
        await m.query(
          "DELETE FROM staff_leave_requests WHERE reason='Phase3 temporary medical leave' AND start_at IN ('2031-07-03T01:00:00Z','2031-07-04T01:00:00Z')",
        );
      });
      console.log("Recovered only marked Phase3 test data");
    } finally {
      await app.close();
    }
    return;
  }
  const appointmentId = "phase3-" + randomUUID();
  try {
    await app.listen(0, "127.0.0.1");
    const base = await app.getUrl();
    async function req(path, method = "GET", body, token) {
      const r = await fetch(base + "/api" + path, {
        method,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: "Bearer " + token } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      return { status: r.status, data: await r.json() };
    }
    async function login(email, password) {
      const r = await req("/auth/login", "POST", { email, password });
      assert.equal(r.status, 200);
      return r.data.accessToken;
    }
    const boss = await login("boss@example.com", "boss123"),
      a = await login("admin@example.com", "admin123"),
      b = await login("manager2@example.com", "manager123"),
      staff = await login("staff@exampler.com", "staff123");
    const profile = (await req("/auth/me", "GET", null, staff)).data;
    const staffId = profile.id;
    assert.ok(staffId);
    assert.equal((await req("/branches/branch-01/shifts")).status, 401);
    assert.equal(
      (await req("/branches/branch-01/shifts", "GET", null, b)).status,
      403,
    );
    const shiftBody = {
      staffId,
      startAt: "2031-07-02T01:00:00Z",
      endAt: "2031-07-02T10:00:00Z",
    };
    assert.equal(
      (await req("/branches/branch-02/shifts", "POST", shiftBody, a)).status,
      403,
    );
    assert.equal(
      (await req("/branches/branch-02/shifts", "POST", shiftBody, b)).status,
      403,
    );
    const shift = await req("/branches/branch-01/shifts", "POST", shiftBody, a);
    assert.equal(shift.status, 201);
    shifts.push(shift.data.id);
    assert.equal(
      (await req("/branches/branch-01/shifts", "POST", shiftBody, a)).status,
      409,
    );
    assert.ok(
      (await req("/staff/me/shifts", "GET", null, staff)).data.some(
        (s) => s.id === shift.data.id,
      ),
    );
    assert.equal(
      (
        await req(
          "/shifts/" + shift.data.id,
          "PATCH",
          { endAt: "2031-07-02T11:00:00Z" },
          b,
        )
      ).status,
      403,
    );
    await db.transaction(async (manager) => {
      const [svc] = await manager.query("SELECT id,name FROM services LIMIT 1");
      await manager.query(
        "INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status) VALUES($1,'branch-01',$2,NULL,'Phase3 test','2031-07-02T02:00:00Z','2031-07-02T02:30:00Z',80000,'confirmed')",
        [appointmentId, staffId],
      );
      await manager.query(
        "INSERT INTO appointment_services(appointment_id,position,service_id,service_name_snapshot) VALUES($1,0,$2,$3)",
        [appointmentId, svc.id, svc.name],
      );
    });
    assert.equal(
      (await req("/shifts/" + shift.data.id, "DELETE", null, a)).status,
      409,
    );
    assert.equal(
      (
        await req(
          "/shifts/" + shift.data.id,
          "PATCH",
          { endAt: "2031-07-02T11:00:00Z" },
          a,
        )
      ).status,
      409,
    );
    await db.query("UPDATE appointments SET status='cancelled' WHERE id=$1", [
      appointmentId,
    ]);
    assert.equal(
      (
        await req(
          "/shifts/" + shift.data.id,
          "PATCH",
          { endAt: "2031-07-02T11:00:00Z" },
          a,
        )
      ).status,
      200,
    );
    const leaveBody = {
      startAt: "2031-07-03T01:00:00Z",
      endAt: "2031-07-03T10:00:00Z",
      reason: "Phase3 temporary medical leave",
    };
    assert.equal(
      (
        await req(
          "/staff/me/leave-requests",
          "POST",
          { ...leaveBody, branchId: "branch-02" },
          staff,
        )
      ).status,
      400,
    );
    const leave = await req(
      "/staff/me/leave-requests",
      "POST",
      leaveBody,
      staff,
    );
    assert.equal(leave.status, 201);
    leaves.push(leave.data.id);
    assert.equal(
      (await req("/staff/me/leave-requests", "POST", leaveBody, staff)).status,
      409,
    );
    assert.ok(
      !(await req("/leave-requests", "GET", null, b)).data.some(
        (l) => l.id === leave.data.id,
      ),
    );
    assert.equal(
      (
        await req(
          "/leave-requests/" + leave.data.id + "/decision",
          "POST",
          { status: "approved" },
          b,
        )
      ).status,
      403,
    );
    const decisions = await Promise.all([
      req(
        "/leave-requests/" + leave.data.id + "/decision",
        "POST",
        { status: "approved" },
        a,
      ),
      req(
        "/leave-requests/" + leave.data.id + "/decision",
        "POST",
        { status: "approved" },
        boss,
      ),
    ]);
    assert.deepEqual(decisions.map((r) => r.status).sort(), [201, 409]);
    const done = decisions.find((r) => r.status === 201).data;
    assert.ok(
      done.reviewedBy &&
        done.reviewedByName &&
        done.reviewedBranchName &&
        done.reviewedAt,
    );
    assert.equal(
      (
        await req(
          "/leave-requests/" + leave.data.id + "/decision",
          "POST",
          { status: "rejected" },
          a,
        )
      ).status,
      409,
    );
    await assert.rejects(
      db.query("UPDATE staff_leave_requests SET note=$2 WHERE id=$1", [
        leave.data.id,
        "tamper",
      ]),
      /immutable/,
    );
    const second = await req(
      "/staff/me/leave-requests",
      "POST",
      {
        ...leaveBody,
        startAt: "2031-07-04T01:00:00Z",
        endAt: "2031-07-04T10:00:00Z",
      },
      staff,
    );
    assert.equal(second.status, 201);
    leaves.push(second.data.id);
    const rejected = await req(
      "/leave-requests/" + second.data.id + "/decision",
      "POST",
      { status: "rejected", note: "Test decision" },
      boss,
    );
    assert.equal(rejected.status, 201);
    assert.equal(
      rejected.data.reviewedByName,
      (await req("/auth/me", "GET", null, boss)).data.name,
    );
    const {
      LeaveRequestsService,
    } = require("./dist/leave-requests/leave-requests.service");
    assert.equal(
      (
        await app
          .get(LeaveRequestsService)
          .approvedOverlaps(
            staffId,
            "branch-01",
            new Date(leaveBody.startAt),
            new Date(leaveBody.endAt),
          )
      ).length,
      1,
    );
    assert.equal(
      (
        await app
          .get(LeaveRequestsService)
          .approvedOverlaps(
            staffId,
            "branch-01",
            new Date("2031-07-04T01:00Z"),
            new Date("2031-07-04T10:00Z"),
          )
      ).length,
      0,
    );
    assert.equal(
      (await req("/shifts/" + shift.data.id, "DELETE", null, a)).status,
      200,
    );
    console.log(
      "Phase3 live PASS: branch/ownership guards, overlap, booked-shift 409, concurrent immutable decisions, Boss snapshots, approved busy intervals",
    );
  } finally {
    await db.transaction(async (manager) => {
      await manager.query(
        "DELETE FROM appointment_services WHERE appointment_id=$1",
        [appointmentId],
      );
      await manager.query("DELETE FROM appointments WHERE id=$1", [
        appointmentId,
      ]);
    });
    if (shifts.length)
      await db.query("DELETE FROM staff_shifts WHERE id=ANY($1::text[])", [
        shifts,
      ]);
    if (leaves.length)
      await db.query(
        "DELETE FROM staff_leave_requests WHERE id=ANY($1::text[])",
        [leaves],
      );
    await app.close();
  }
})().catch((e) => {
  console.error(e.message);
  process.exitCode = 1;
});
