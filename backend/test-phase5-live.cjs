require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict"),
  { randomUUID } = require("node:crypto");
const { NestFactory } = require("@nestjs/core"),
  { ValidationPipe } = require("@nestjs/common"),
  { DataSource } = require("typeorm");
const { AppModule } = require("./dist/app.module");
const { reportPeriods } = require("./dist/reports/report-period");
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
    ids = [];
  try {
    await app.listen(0, "127.0.0.1");
    const base = (await app.getUrl()) + "/api";
    async function req(path, method = "GET", body, token) {
      const r = await fetch(base + path, {
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
      manager = await login("admin@example.com", "admin123"),
      managerB = await login("manager2@example.com", "manager123"),
      customer = await login("customer@example.com", "customer123");
    if (process.argv.includes("--verify-server")) {
      for (const path of [
        "/boss/dashboard",
        "/boss/leaderboards",
        "/boss/appointments",
        "/boss/commissions",
      ]) {
        const r = await fetch("http://localhost:3000/api" + path, {
          headers: { Authorization: "Bearer " + boss },
        });
        assert.equal(r.status, 200);
      }
      // Tokens signed by the same server config, validated against live user/version.
      const r = await fetch("http://localhost:3000/api/manager/revenue", {
        headers: { Authorization: "Bearer " + manager },
      });
      assert.equal(r.status, 200);
      const staffToken = await login("staff@exampler.com", "staff123");
      for (const path of [
        "/staff/me/earnings",
        "/staff/me/profile-stats",
        "/manager/dashboard",
      ]) {
        const response = await fetch("http://localhost:3000/api" + path, {
          headers: {
            Authorization:
              "Bearer " + (path.startsWith("/staff") ? staffToken : manager),
          },
        });
        assert.equal(response.status, 200);
      }
      const [counts] = await db.query(
        "SELECT (SELECT count(*)::int FROM users WHERE email LIKE 'phase5-%') AS test_users,(SELECT count(*)::int FROM appointments WHERE id LIKE 'phase5-%') AS test_appointments,(SELECT count(*)::int FROM staff_shifts WHERE id LIKE 'seed-shift-%') AS seed_shifts",
      );
      assert.equal(counts.test_users, 0);
      assert.equal(counts.test_appointments, 0);
      console.log(
        JSON.stringify({
          server: "localhost:3000",
          reportsEndpoints: 8,
          status: 200,
          ...counts,
        }),
      );
      return;
    }
    const baseline = (await req("/manager/dashboard", "GET", null, manager))
      .data;
    async function staff(token) {
      const email = "phase5-" + randomUUID() + "@example.com";
      const r = await req(
        "/users/staff",
        "POST",
        {
          name: "Phase5 test Staff",
          email,
          phone: "0901234567",
          address: "Ha Noi",
          specializedCategoryIds: ["haircut"],
        },
        token,
      );
      assert.equal(r.status, 201);
      users.push(r.data.id);
      assert.equal(
        (
          await req(
            "/users/" + r.data.id + "/approve",
            "POST",
            { password: "Phase5Staff123" },
            boss,
          )
        ).status,
        200,
      );
      return {
        id: r.data.id,
        branchId: r.data.branchId,
        token: await login(email, "Phase5Staff123"),
      };
    }
    const a = await staff(manager),
      b = await staff(managerB),
      periods = reportPeriods();
    const customers = await db.query(
        "SELECT id FROM users WHERE role='customer' ORDER BY id LIMIT 2",
      ),
      services = await db.query(
        "SELECT id,name FROM services ORDER BY id LIMIT 2",
      );
    const day = +periods.day.from,
      month = +periods.month.from;
    const fixtures = [
      {
        staff: a,
        time: month + 13 * 3600000,
        price: 10n,
        status: "completed",
        customer: customers[1].id,
      },
      {
        staff: a,
        time: day,
        price: 9007199254740993n,
        status: "completed",
        customer: customers[0].id,
        rating: 5,
        hidden: true,
      },
      {
        staff: a,
        time: day + 3600000,
        price: 80001n,
        status: "completed",
        customer: customers[0].id,
        rating: 3,
      },
      {
        staff: a,
        time: day + 2 * 3600000,
        price: 1000000n,
        status: "cancelled",
        customer: customers[0].id,
        rating: 1,
      },
      {
        staff: a,
        time: day + 3 * 3600000,
        price: 7000000n,
        status: "noShow",
        customer: customers[0].id,
      },
      {
        staff: a,
        time: day + 5 * 3600000,
        price: 100n,
        status: "completed",
        customer: null,
      },
      {
        staff: a,
        time: day + 6 * 3600000,
        price: 101n,
        status: "completed",
        customer: null,
      },
      {
        staff: a,
        time: +periods.day.to - 3600000,
        price: 80000n,
        status: "confirmed",
        customer: customers[0].id,
      },
      {
        staff: a,
        time: day - 3600000,
        price: 19n,
        status: "completed",
        customer: customers[0].id,
      },
      {
        staff: a,
        time: +periods.day.to,
        price: 99n,
        status: "completed",
        customer: customers[0].id,
      },
      {
        staff: a,
        time: +periods.month.to,
        price: 27n,
        status: "completed",
        customer: customers[1].id,
      },
      {
        staff: b,
        time: day,
        price: 100000n,
        status: "completed",
        customer: customers[0].id,
      },
    ];
    await db.transaction(async (m) => {
      for (const f of fixtures) {
        const id = "phase5-" + randomUUID();
        ids.push(id);
        f.id = id;
        await m.query(
          "INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status,is_hidden_by_customer,is_hidden_by_staff,is_reviewed,rating) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$10,$11,$12)",
          [
            id,
            f.staff.branchId,
            f.staff.id,
            f.customer,
            "Phase5 test customer",
            new Date(f.time),
            new Date(f.time + 15 * 60000),
            f.price.toString(),
            f.status,
            !!f.hidden,
            !!f.rating,
            f.rating ?? null,
          ],
        );
        for (let position = 0; position < 2; position++)
          await m.query(
            "INSERT INTO appointment_services(appointment_id,position,service_id,service_name_snapshot) VALUES($1,$2,$3,$4)",
            [id, position, services[position].id, services[position].name],
          );
      }
    });
    const completed = (staff, period) =>
      fixtures.filter(
        (f) =>
          f.staff.id === staff.id &&
          f.status === "completed" &&
          f.time >= +period.from &&
          f.time < +period.to,
      );
    const total = (rows) => rows.reduce((v, f) => v + f.price, 0n).toString();
    const daily = completed(a, periods.day),
      monthly = completed(a, periods.month);
    assert.equal((await req("/manager/dashboard")).status, 401);
    assert.equal(
      (await req("/manager/dashboard", "GET", null, customer)).status,
      403,
    );
    assert.equal(
      (await req("/boss/dashboard", "GET", null, manager)).status,
      403,
    );
    const dash = (
      await req("/manager/dashboard?branchId=branch-02", "GET", null, manager)
    ).data;
    assert.equal(dash.branchId, "branch-01");
    assert.equal(
      BigInt(dash.today.revenueVnd) - BigInt(baseline.today.revenueVnd),
      BigInt(total(daily)),
    );
    assert.equal(
      dash.today.completedCount - baseline.today.completedCount,
      daily.length,
    );
    assert.ok(dash.upcoming.every((row) => row.branchId === "branch-01"));
    assert.ok(dash.upcoming.some((row) => row.id === fixtures[7].id));
    const date = new Date(day + 7 * 3600000).toISOString().slice(0, 10),
      range = "?from=" + date + "&to=" + date;
    const revenue = await req("/manager/revenue" + range, "GET", null, manager);
    assert.equal(revenue.status, 200);
    assert.equal(
      BigInt(revenue.data.revenueVnd) - BigInt(baseline.today.revenueVnd),
      BigInt(total(daily)),
    );
    assert.ok(
      revenue.data.transactions.every(
        (row) => row.branchId === "branch-01" && row.status === "completed",
      ),
    );
    assert.ok(
      revenue.data.transactions.find((row) => row.id === fixtures[1].id)
        .services.length === 2,
    );
    assert.equal(
      (
        await req(
          "/manager/revenue" + range + "&branchId=branch-02",
          "GET",
          null,
          manager,
        )
      ).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/manager/revenue?from=2026-02-30&to=2026-03-01",
          "GET",
          null,
          manager,
        )
      ).status,
      400,
    );
    const rank = revenue.data.staffRanking.find((row) => row.staffId === a.id);
    assert.equal(rank.revenueVnd, total(daily));
    assert.equal(rank.completedCount, daily.length);
    const bossBranch = (
      await req("/boss/dashboard?branchId=branch-01", "GET", null, boss)
    ).data;
    assert.equal(bossBranch.today.revenueVnd, dash.today.revenueVnd);
    const leaders = (await req("/boss/leaderboards", "GET", null, boss)).data;
    assert.equal(
      leaders.staff.find((row) => row.staffId === a.id).completedCount,
      monthly.length,
    );
    const commission = (
      await req("/boss/commissions?branchId=branch-01", "GET", null, boss)
    ).data.staff.find((row) => row.staffId === a.id);
    assert.equal(commission.revenueVnd, total(monthly));
    assert.equal(
      commission.commissionVnd,
      ((BigInt(total(monthly)) * 30n) / 100n).toString(),
    );
    const ledger = (
      await req(
        "/boss/appointments" + range + "&branchId=branch-01&status=completed",
        "GET",
        null,
        boss,
      )
    ).data.appointments;
    assert.ok(
      ledger.every(
        (row) => row.branchId === "branch-01" && row.status === "completed",
      ),
    );
    assert.ok(ledger.find((row) => row.id === fixtures[1].id).branchName);
    assert.ok(!ledger.some((row) => row.id === fixtures[9].id));
    const earnings = (await req("/staff/me/earnings", "GET", null, a.token))
      .data;
    assert.equal(earnings.today.revenueVnd, total(daily));
    assert.equal(earnings.month.revenueVnd, total(monthly));
    assert.ok(earnings.transactions.every((row) => row.staffId === a.id));
    assert.equal(
      (await req("/staff/me/earnings?staffId=" + b.id, "GET", null, a.token))
        .status,
      400,
    );
    const profile = (await req("/staff/me/profile-stats", "GET", null, a.token))
      .data;
    assert.equal(profile.monthly.completedCount, monthly.length);
    assert.equal(profile.reviewCount, 2);
    assert.equal(profile.averageRating, 4);
    assert.equal(profile.registeredCustomerCount, 2);
    assert.equal(profile.walkInCompletedCount, 2);
    assert.equal(profile.customers.length, 2);
    assert.ok(
      profile.customers.every((row) => typeof row.totalSpentVnd === "string"),
    );
    // A transferred Staff must remain one Boss ranking/commission row, preserving
    // branch snapshots on old appointments rather than moving old revenue.
    const transferredId = "phase5-" + randomUUID();
    ids.push(transferredId);
    await db.transaction(async (m) => {
      await m.query("UPDATE users SET branch_id='branch-01' WHERE id=$1", [
        b.id,
      ]);
      await m.query(
        "INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status) VALUES($1,'branch-01',$2,$3,'Phase5 transfer', $4,$5,33333,'completed')",
        [
          transferredId,
          b.id,
          customers[0].id,
          new Date(day + 7 * 3600000),
          new Date(day + 7 * 3600000 + 15 * 60000),
        ],
      );
      await m.query(
        "INSERT INTO appointment_services(appointment_id,position,service_id,service_name_snapshot) VALUES($1,0,$2,$3)",
        [transferredId, services[0].id, services[0].name],
      );
    });
    const afterTransfer = (
      await req("/boss/leaderboards", "GET", null, boss)
    ).data.staff.filter((row) => row.staffId === b.id);
    assert.equal(afterTransfer.length, 1);
    assert.equal(afterTransfer[0].completedCount, 2);
    assert.equal(afterTransfer[0].branches.length, 2);
    const transferredCommission = (
      await req("/boss/commissions", "GET", null, boss)
    ).data.staff.find((row) => row.staffId === b.id);
    assert.equal(transferredCommission.revenueVnd, "133333");
    assert.equal(transferredCommission.commissionVnd, "39999");
    console.log(
      JSON.stringify({
        phase5: "PASS",
        dailyRevenueVnd: total(daily),
        commissionVnd: commission.commissionVnd,
        verified: [
          "Hanoi day/month bounds",
          "completed-only/no double SUM with 2 items",
          "BIGINT exact strings",
          "role/branch/staff scopes",
          "hidden counted",
          "walk-in not grouped as customer",
          "reviews and LTV",
          "ledger filters",
        ],
      }),
    );
  } finally {
    await db.transaction(async (m) => {
      if (ids.length)
        await m.query("DELETE FROM appointments WHERE id=ANY($1::text[])", [
          ids,
        ]);
      if (users.length)
        await m.query("DELETE FROM users WHERE id=ANY($1::text[])", [users]);
    });
    await app.close();
  }
})().catch((error) => {
  console.error(error.stack);
  process.exitCode = 1;
});
