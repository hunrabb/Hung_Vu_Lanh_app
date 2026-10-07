require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict"),
  { randomUUID } = require("node:crypto");
const { NestFactory } = require("@nestjs/core"),
  { ValidationPipe } = require("@nestjs/common"),
  { DataSource } = require("typeorm");
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
    users = [],
    services = [],
    appointments = [],
    shifts = [],
    leaves = [];
  if (process.argv.includes("--verify-server")) {
    try {
      const base = "http://localhost:3000/api";
      const catalog = await fetch(base + "/services");
      assert.equal(catalog.status, 200);
      let available;
      const date = new Date(Date.now() + 7 * 3600000 + 86400000)
        .toISOString()
        .slice(0, 10);
      for (const service of (await catalog.json()).filter((s) => s.isActive)) {
        const directory = await fetch(
          base + "/branches/branch-01/staff?serviceId=" + service.id,
        );
        assert.equal(directory.status, 200);
        const staff = (await directory.json())[0];
        if (!staff) continue;
        const response = await fetch(
          base +
            "/booking/available-slots?branchId=branch-01&staffId=" +
            staff.id +
            "&date=" +
            date +
            "&serviceIds=" +
            service.id,
        );
        assert.equal(response.status, 200);
        available = await response.json();
        if (available.slots.length) break;
      }
      assert.ok(available?.slots.length);
      const login = await fetch(base + "/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email: "admin@example.com",
          password: "admin123",
        }),
      });
      assert.equal(login.status, 200);
      const { accessToken } = await login.json();
      const ledger = await fetch(base + "/appointments", {
        headers: { Authorization: "Bearer " + accessToken },
      });
      assert.equal(ledger.status, 200);
      const [counts] = await db.query(
        "SELECT (SELECT count(*)::int FROM staff_shifts WHERE id LIKE 'seed-shift-%') AS seed_shifts,(SELECT count(*)::int FROM users WHERE email LIKE 'phase4-%') AS test_users,(SELECT count(*)::int FROM services WHERE name LIKE 'Phase4 %') AS test_services",
      );
      assert.equal(counts.test_users, 0);
      assert.equal(counts.test_services, 0);
      console.log(
        JSON.stringify({
          server: "localhost:3000",
          staffDirectoryStatus: 200,
          slotsStatus: 200,
          appointmentsStatus: 200,
          date,
          availableSlots: available.slots.length,
          ...counts,
        }),
      );
    } finally {
      await app.close();
    }
    return;
  }
  try {
    await app.listen(0, "127.0.0.1");
    const base = (await app.getUrl()) + "/api";
    async function req(path, method = "GET", body, token) {
      const response = await fetch(base + path, {
        method,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: "Bearer " + token } : {}),
        },
        ...(body !== undefined && body !== null
          ? { body: JSON.stringify(body) }
          : {}),
      });
      const data = await response.json();
      if (
        method === "POST" &&
        path.startsWith("/appointments") &&
        response.status === 201 &&
        data.id
      )
        appointments.push(data.id);
      return { status: response.status, data };
    }
    async function login(email, password) {
      const response = await req("/auth/login", "POST", { email, password });
      assert.equal(response.status, 200);
      return response.data.accessToken;
    }
    const boss = await login("boss@example.com", "boss123"),
      managerA = await login("admin@example.com", "admin123"),
      managerB = await login("manager2@example.com", "manager123"),
      customerA = await login("customer@example.com", "customer123"),
      customerB = await login("customer2@example.com", "customer123");
    async function newStaff(manager, category = "haircut") {
      const email = "phase4-" + randomUUID() + "@example.com";
      const profile = await req(
        "/users/staff",
        "POST",
        {
          email,
          name: "Phase4 temporary Staff",
          phone: "0901234567",
          address: "Ha Noi",
          specializedCategoryIds: [category],
        },
        manager,
      );
      assert.equal(profile.status, 201);
      users.push(profile.data.id);
      const list = await req(
        "/branches/" +
          profile.data.branchId +
          "/staff?serviceId=" +
          services[0],
      );
      assert.equal(list.status, 200);
      assert.ok(!list.data.some((s) => s.id === profile.data.id));
      assert.equal(
        (
          await req(
            "/users/" + profile.data.id + "/approve",
            "POST",
            { password: "Phase4Staff123" },
            boss,
          )
        ).status,
        200,
      );
      return {
        id: profile.data.id,
        token: await login(email, "Phase4Staff123"),
      };
    }
    async function newService(name, duration, price, categoryId = "haircut") {
      const response = await req(
        "/services",
        "POST",
        { name: "Phase4 " + name, categoryId, duration, price, isActive: true },
        boss,
      );
      assert.equal(response.status, 201);
      services.push(response.data.id);
      return response.data.id;
    }
    const s1 = await newService("Cut", 45, "80000"),
      s2 = await newService("Style", 30, "50000"),
      wrong = await newService("Wrong category", 15, "50000", "massage");
    const a = await newStaff(managerA),
      b = await newStaff(managerB);
    for (const [staff, branchId, manager] of [
      [a, "branch-01", managerA],
      [b, "branch-02", managerB],
    ])
      for (const date of [
        "2033-06-20",
        "2033-06-21",
        "2033-06-22",
        "2033-06-23",
      ])
        for (const [from, to] of [
          ["01:00", "05:00"],
          ["06:00", "10:00"],
        ]) {
          const response = await req(
            "/branches/" + branchId + "/shifts",
            "POST",
            {
              staffId: staff.id,
              startAt: date + "T" + from + ":00Z",
              endAt: date + "T" + to + ":00Z",
            },
            manager,
          );
          assert.equal(response.status, 201);
          shifts.push(response.data.id);
        }
    const eligible = await req("/branches/branch-01/staff?serviceId=" + s1);
    assert.equal(eligible.status, 200);
    assert.ok(eligible.data.some((s) => s.id === a.id));
    assert.ok(!eligible.data.some((s) => s.id === b.id));
    assert.ok(eligible.data.every((s) => !("email" in s) && !("phone" in s)));
    function slotPath(staff, branch, date, ids = [s1]) {
      return (
        "/booking/available-slots?branchId=" +
        branch +
        "&staffId=" +
        staff.id +
        "&date=" +
        date +
        "&serviceIds=" +
        ids.join(",")
      );
    }
    const available = await req(
      slotPath(a, "branch-01", "2033-06-20", [s1, s2]),
    );
    assert.equal(available.status, 200);
    assert.equal(available.data.totalDurationMinutes, 75);
    assert.equal(available.data.totalPriceVnd, "130000");
    assert.ok(available.data.slots.length);
    assert.ok(
      available.data.slots.every((slot) => {
        const start = +new Date(slot.startAt),
          end = +new Date(slot.endAt);
        return (
          end <= Date.parse("2033-06-20T05:00Z") ||
          start >= Date.parse("2033-06-20T06:00Z")
        );
      }),
    );
    assert.deepEqual(
      (await req(slotPath(a, "branch-01", "2033-06-25"))).data.slots,
      [],
    );
    assert.equal(
      (await req(slotPath(a, "branch-02", "2033-06-20"))).status,
      400,
    );
    assert.equal(
      (await req(slotPath(a, "branch-01", "2033-06-20", [wrong]))).status,
      400,
    );
    assert.equal(
      (await req(slotPath(a, "branch-01", "2033-02-30"))).status,
      400,
    );
    // Uncommitted settings probes are rolled back; existing seed is never changed.
    const { BookingService } = require("./dist/appointments/booking.service");
    const rollback = new Error("rollback settings probe");
    await assert.rejects(
      db.transaction(async (m) => {
        const query = {
          branchId: "branch-01",
          staffId: a.id,
          serviceIds: [s1],
          date: "2033-06-20",
        };
        await m.query(
          "UPDATE shop_settings SET closed_dates=ARRAY['2033-06-20']::date[] WHERE branch_id='branch-01'",
        );
        assert.deepEqual(
          (await app.get(BookingService).context(m, query)).slots,
          [],
        );
        await m.query(
          "UPDATE shop_settings SET closed_dates='{}',closed_weekdays=ARRAY[1]::smallint[] WHERE branch_id='branch-01'",
        );
        assert.deepEqual(
          (await app.get(BookingService).context(m, query)).slots,
          [],
        );
        await m.query(
          "UPDATE shop_settings SET closed_weekdays='{}',opening_minute=600,closing_minute=660 WHERE branch_id='branch-01'",
        );
        const narrowed = await app.get(BookingService).context(m, query);
        assert.ok(narrowed.slots.length);
        assert.ok(
          narrowed.slots.every(
            (slot) =>
              Date.parse(slot.startAt) >= Date.parse("2033-06-20T03:00:00Z") &&
              Date.parse(slot.endAt) <= Date.parse("2033-06-20T04:00:00Z"),
          ),
        );
        throw rollback;
      }),
      (error) => error === rollback,
    );
    const body = {
      branchId: "branch-01",
      staffId: a.id,
      serviceIds: [s1, s2],
      startAt: available.data.slots[0].startAt,
    };
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, totalPriceVnd: "1" },
          customerA,
        )
      ).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, customerId: users[1] },
          customerA,
        )
      ).status,
      400,
    );
    assert.equal(
      (await req("/appointments", "POST", body, managerA)).status,
      403,
    );
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, startAt: "2033-06-20T04:30:00Z" },
          customerA,
        )
      ).status,
      409,
    );
    const concurrent = await Promise.all([
      req("/appointments", "POST", body, customerA),
      req("/appointments", "POST", body, customerB),
    ]);
    assert.deepEqual(concurrent.map((r) => r.status).sort(), [201, 409]);
    const winner = concurrent.find((r) => r.status === 201).data;
    assert.equal(winner.totalPriceVnd, "130000");
    assert.equal(winner.services.length, 2);
    assert.equal(winner.branchId, "branch-01");
    const ownerA = (await req("/auth/me", "GET", null, customerA)).data.id;
    const ownerToken = winner.customerId === ownerA ? customerA : customerB,
      otherToken = ownerToken === customerA ? customerB : customerA;
    const [count] = await db.query(
      "SELECT count(*)::int AS n FROM appointments WHERE staff_id=$1 AND start_at=$2",
      [a.id, body.startAt],
    );
    assert.equal(count.n, 1);
    assert.ok(
      (await req("/appointments", "GET", null, ownerToken)).data.some(
        (row) => row.id === winner.id,
      ),
    );
    assert.ok(
      !(await req("/appointments", "GET", null, otherToken)).data.some(
        (row) => row.id === winner.id,
      ),
    );
    assert.equal(
      (await req("/appointments?branchId=branch-01", "GET", null, managerB))
        .status,
      403,
    );
    assert.ok(
      !(await req("/appointments", "GET", null, managerB)).data.some(
        (row) => row.id === winner.id,
      ),
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/cancel",
          "POST",
          {},
          otherToken,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/complete",
          "POST",
          {},
          b.token,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/no-show",
          "POST",
          {},
          managerB,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/complete",
          "POST",
          {},
          a.token,
        )
      ).status,
      201,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/cancel",
          "POST",
          {},
          ownerToken,
        )
      ).status,
      409,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/hide/customer",
          "POST",
          {},
          ownerToken,
        )
      ).status,
      201,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + winner.id + "/hide/staff",
          "POST",
          {},
          a.token,
        )
      ).status,
      201,
    );
    assert.ok(
      !(await req("/appointments", "GET", null, ownerToken)).data.some(
        (row) => row.id === winner.id,
      ),
    );
    assert.ok(
      (await req("/appointments", "GET", null, managerA)).data.some(
        (row) =>
          row.id === winner.id && row.isHiddenByCustomer && row.isHiddenByStaff,
      ),
    );
    assert.ok(
      !(
        await req(slotPath(a, "branch-01", "2033-06-20", [s1, s2]))
      ).data.slots.some((slot) => slot.startAt === body.startAt),
    );
    // Adjacent boundary allowed; completed appointment remains a blocking interval.
    const adjacent = await req(
      "/appointments",
      "POST",
      { ...body, startAt: winner.endAt },
      customerA,
    );
    assert.equal(adjacent.status, 201);
    await assert.rejects(
      db.transaction(async (m) => {
        await m.query(
          "INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status) VALUES($1,'branch-01',$2,$3,'test',$4,$5,1,'confirmed')",
          [
            "phase4-overlap-" + randomUUID(),
            a.id,
            winner.customerId,
            winner.startAt,
            winner.endAt,
          ],
        );
      }),
      (e) => e.code === "23P01",
    );
    const failedId = "phase4-noitems-" + randomUUID();
    await assert.rejects(
      db.transaction(async (m) => {
        await m.query(
          "INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status) VALUES($1,'branch-01',$2,$3,'test','2033-06-25T01:00Z','2033-06-25T02:00Z',1,'confirmed')",
          [failedId, a.id, ownerA],
        );
      }),
      /at least one service/,
    );
    assert.equal(
      (await db.query("SELECT id FROM appointments WHERE id=$1", [failedId]))
        .length,
      0,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + adjacent.data.id + "/cancel",
          "POST",
          {},
          customerA,
        )
      ).status,
      201,
    );
    const walk = await req(
      "/appointments/walk-in",
      "POST",
      {
        staffId: a.id,
        serviceIds: [s1],
        startAt: adjacent.data.startAt,
        customerName: "Phase4 Walk-in / 0901234567",
      },
      managerA,
    );
    assert.equal(walk.status, 201);
    assert.equal(walk.data.customerId, null);
    assert.equal(walk.data.branchId, "branch-01");
    assert.equal(
      (
        await req(
          "/appointments/walk-in",
          "POST",
          {
            staffId: a.id,
            serviceIds: [s1],
            startAt: "2033-06-20T08:00:00Z",
            customerName: "Wrong branch",
          },
          managerB,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await req(
          "/appointments/walk-in",
          "POST",
          {
            staffId: a.id,
            serviceIds: [s1],
            startAt: "2033-06-20T08:00:00Z",
            customerName: "Spoof",
            branchId: "branch-02",
          },
          managerA,
        )
      ).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/appointments/" + walk.data.id + "/no-show",
          "POST",
          {},
          managerA,
        )
      ).status,
      201,
    );
    // Pending leave does not block, approval does; approval and booking share Staff lock.
    const leaveBody = {
      startAt: "2033-06-21T01:00:00Z",
      endAt: "2033-06-21T03:00:00Z",
      reason: "Phase4 test leave",
    };
    const leave = await req(
      "/staff/me/leave-requests",
      "POST",
      leaveBody,
      a.token,
    );
    assert.equal(leave.status, 201);
    leaves.push(leave.data.id);
    assert.ok(
      (await req(slotPath(a, "branch-01", "2033-06-21"))).data.slots.some(
        (s) => Date.parse(s.startAt) === Date.parse(leaveBody.startAt),
      ),
    );
    assert.equal(
      (
        await req(
          "/leave-requests/" + leave.data.id + "/decision",
          "POST",
          { status: "approved" },
          managerA,
        )
      ).status,
      201,
    );
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, serviceIds: [s1], startAt: leaveBody.startAt },
          customerA,
        )
      ).status,
      409,
    );
    assert.ok(
      !(await req(slotPath(a, "branch-01", "2033-06-21"))).data.slots.some(
        (s) => Date.parse(s.startAt) === Date.parse(leaveBody.startAt),
      ),
    );
    const raceLeave = await req(
      "/staff/me/leave-requests",
      "POST",
      {
        ...leaveBody,
        startAt: "2033-06-22T01:00:00Z",
        endAt: "2033-06-22T03:00:00Z",
      },
      a.token,
    );
    assert.equal(raceLeave.status, 201);
    leaves.push(raceLeave.data.id);
    const [decision, raceBooking] = await Promise.all([
      req(
        "/leave-requests/" + raceLeave.data.id + "/decision",
        "POST",
        { status: "approved" },
        managerA,
      ),
      req(
        "/appointments",
        "POST",
        { ...body, serviceIds: [s1], startAt: "2033-06-22T01:00:00Z" },
        customerA,
      ),
    ]);
    assert.equal(decision.status, 201);
    assert.ok([201, 409].includes(raceBooking.status));
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, serviceIds: [s1], startAt: "2033-06-22T01:00:00Z" },
          customerA,
        )
      ).status,
      409,
    );
    // Re-read specialization and active price rather than trusting stale GET.
    assert.equal(
      (
        await req(
          "/services/" + s1,
          "PATCH",
          { price: "9007199254740993" },
          boss,
        )
      ).status,
      200,
    );
    const exact = await req(
      "/appointments",
      "POST",
      { ...body, serviceIds: [s1], startAt: "2033-06-23T01:00:00Z" },
      customerA,
    );
    assert.equal(exact.status, 201);
    assert.equal(exact.data.totalPriceVnd, "9007199254740993");
    assert.equal(
      (await req("/services/" + s1, "PATCH", { isActive: false }, boss)).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, serviceIds: [s1], startAt: "2033-06-23T02:00:00Z" },
          customerA,
        )
      ).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/users/staff/" + a.id,
          "PATCH",
          { specializedCategoryIds: ["massage"] },
          managerA,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/appointments",
          "POST",
          { ...body, serviceIds: [s2], startAt: "2033-06-23T03:00:00Z" },
          customerA,
        )
      ).status,
      400,
    );
    const [persisted] = await db.query(
      "SELECT total_price_vnd FROM appointments WHERE id=$1",
      [winner.id],
    );
    assert.equal(persisted.total_price_vnd, "130000");
    console.log(
      JSON.stringify({
        phase4: "PASS",
        concurrentStatuses: concurrent.map((r) => r.status).sort(),
        singleBookingCount: count.n,
        leaveRace: raceBooking.status,
        verified: [
          "Hanoi/shifts/breaks",
          "multi-service price/duration",
          "DTO/tenant/ownership/state",
          "adjacent/EXCLUDE 23P01",
          "item commit rollback",
          "approved leave/race",
          "BIGINT/stale catalog/specialization",
          "independent soft hides",
        ],
      }),
    );
  } finally {
    await db.transaction(async (m) => {
      if (appointments.length)
        await m.query("DELETE FROM appointments WHERE id=ANY($1::text[])", [
          appointments,
        ]);
      if (shifts.length)
        await m.query("DELETE FROM staff_shifts WHERE id=ANY($1::text[])", [
          shifts,
        ]);
      if (leaves.length)
        await m.query(
          "DELETE FROM staff_leave_requests WHERE id=ANY($1::text[])",
          [leaves],
        );
      if (users.length)
        await m.query("DELETE FROM users WHERE id=ANY($1::text[])", [users]);
      if (services.length)
        await m.query("DELETE FROM services WHERE id=ANY($1::text[])", [
          services,
        ]);
    });
    await app.close();
  }
})().catch((error) => {
  console.error(error.stack);
  process.exitCode = 1;
});
