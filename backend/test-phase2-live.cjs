require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
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
  const userIds = [];
  let branchId, serviceId;
  const appointmentId = "phase2-" + crypto.randomUUID(),
    shiftId = "phase2-" + crypto.randomUUID();
  let originalCategory;
  const db = app.get(DataSource);
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
        ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      });
      const data = await r.json();
      return { status: r.status, data };
    }
    async function login(email, password) {
      const r = await req("/auth/login", "POST", { email, password });
      assert.equal(r.status, 200);
      return r.data.accessToken;
    }
    const boss = await login("boss@example.com", "boss123"),
      manager = await login("admin@example.com", "admin123"),
      managerB = await login("manager2@example.com", "manager123");
    for (const p of ["/branches", "/services", "/categories"])
      assert.equal((await req(p)).status, 200);
    const payload = {
      name: "Phase2 temporary Staff",
      email: "phase2-" + crypto.randomUUID() + "@example.com",
      phone: "0901234567",
      address: "Hà Nội",
      specializedCategoryIds: ["haircut", "hairWash"],
    };
    assert.equal(
      (
        await req(
          "/users/staff",
          "POST",
          { ...payload, branchId: "branch-02" },
          manager,
        )
      ).status,
      400,
    );
    assert.equal(
      (await req("/users/staff", "POST", payload, boss)).status,
      403,
    );
    const created = await req("/users/staff", "POST", payload, manager);
    assert.equal(created.status, 201);
    const id = created.data.id;
    userIds.push(id);
    assert.equal(created.data.role, "staff");
    assert.equal(created.data.isApproved, false);
    assert.equal(created.data.branchId, "branch-01");
    assert.equal(
      (
        await db.query(
          "SELECT count(*) FROM auth_credentials WHERE user_id=$1",
          [id],
        )
      )[0].count,
      "0",
    );
    assert.equal(
      (
        await req(
          "/users/staff/" + id,
          "PATCH",
          { name: "Forbidden" },
          managerB,
        )
      ).status,
      403,
    );
    assert.equal(
      (await req("/users/staff/" + id, "PATCH", { isApproved: true }, manager))
        .status,
      400,
    );
    assert.equal(
      (await req("/users/staff/" + id, "PATCH", {}, manager)).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/users/staff/" + id,
          "PATCH",
          { name: "Phase2 updated Staff" },
          manager,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/users/" + id + "/approve",
          "POST",
          { password: "Staff123!" },
          manager,
        )
      ).status,
      403,
    );
    const approvals = await Promise.all([
      req("/users/" + id + "/approve", "POST", { password: "Staff123!" }, boss),
      req("/users/" + id + "/approve", "POST", { password: "Staff123!" }, boss),
    ]);
    assert.deepEqual(approvals.map((r) => r.status).sort(), [200, 409]);
    assert.equal(
      (
        await db.query(
          "SELECT count(*) FROM auth_credentials WHERE user_id=$1",
          [id],
        )
      )[0].count,
      "1",
    );
    const staff = await login(payload.email, "Staff123!");
    assert.equal(
      (await req("/users/pending", "GET", undefined, staff)).status,
      403,
    );
    assert.equal(
      (await req("/users/" + id + "/pending", "DELETE", undefined, boss))
        .status,
      409,
    );
    const pendingPayload = {
      ...payload,
      email: "phase2-" + crypto.randomUUID() + "@example.com",
    };
    const pending = await req("/users/staff", "POST", pendingPayload, manager);
    assert.equal(pending.status, 201);
    userIds.push(pending.data.id);
    await db.query(
      "INSERT INTO staff_shifts(id,staff_id,branch_id,start_at,end_at) VALUES ($1,$2,$3,$4,$5)",
      [
        shiftId,
        pending.data.id,
        "branch-01",
        "2030-01-02T01:00:00Z",
        "2030-01-02T02:00:00Z",
      ],
    );
    assert.equal(
      (
        await req(
          "/users/" + pending.data.id + "/pending",
          "DELETE",
          undefined,
          boss,
        )
      ).status,
      409,
    );
    await db.query("DELETE FROM staff_shifts WHERE id=$1", [shiftId]);
    assert.equal(
      (
        await req(
          "/users/" + pending.data.id + "/pending",
          "DELETE",
          undefined,
          boss,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/branches",
          "POST",
          { name: "Forbidden", address: "Hà Nội", phone: "0901234567" },
          manager,
        )
      ).status,
      403,
    );
    const branch = await req(
      "/branches",
      "POST",
      {
        name: "Phase2 temporary Branch",
        address: "Hà Nội",
        phone: "0901234567",
      },
      boss,
    );
    assert.equal(branch.status, 201);
    branchId = branch.data.id;
    assert.equal(
      (
        await req(
          "/branches/" + branchId,
          "PATCH",
          { name: "Phase2 updated Branch" },
          boss,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/branches/" + branchId + "/settings",
          "PATCH",
          { openingMinute: 540 },
          manager,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await req(
          "/branches/" + branchId + "/settings",
          "PATCH",
          {
            openingMinute: 540,
            closingMinute: 1080,
            closedWeekdays: [7],
            closedDates: ["2030-01-02"],
          },
          boss,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/branches/" + branchId + "/settings",
          "PATCH",
          { closingMinute: 100 },
          boss,
        )
      ).status,
      400,
    );
    assert.equal(
      (await req("/branches/branch-01", "DELETE", undefined, boss)).status,
      409,
    );
    const original = (
      await db.query(
        "SELECT opening_minute,closing_minute FROM shop_settings WHERE branch_id='branch-01'",
      )
    )[0];
    assert.equal(
      (
        await req(
          "/branches/branch-01/settings",
          "PATCH",
          {
            openingMinute: original.opening_minute,
            closingMinute: original.closing_minute,
          },
          manager,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await req(
          "/services",
          "POST",
          { name: "Bad", categoryId: "haircut", price: -1, duration: 30 },
          boss,
        )
      ).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/services",
          "POST",
          {
            name: "Forbidden",
            categoryId: "haircut",
            price: 80000,
            duration: 30,
          },
          manager,
        )
      ).status,
      403,
    );
    const service = await req(
      "/services",
      "POST",
      {
        name: "Phase2 temporary Service",
        categoryId: "haircut",
        price: "9007199254740993",
        duration: 30,
      },
      boss,
    );
    assert.equal(service.status, 201);
    serviceId = service.data.id;
    assert.equal(service.data.price, "9007199254740993");
    assert.equal(
      (
        await req(
          "/services/" + serviceId,
          "PATCH",
          { price: "80000", duration: 45, isActive: false },
          boss,
        )
      ).status,
      200,
    );
    const tx = db.createQueryRunner();
    await tx.connect();
    await tx.startTransaction();
    try {
      await tx.query(
        "INSERT INTO appointments(id,branch_id,staff_id,customer_id,customer_name,start_at,end_at,total_price_vnd,status) VALUES ($1,'branch-01',$2,NULL,'Phase2 walk-in','2030-01-03T01:00:00Z','2030-01-03T01:45:00Z',80000,'confirmed')",
        [appointmentId, id],
      );
      await tx.query(
        "INSERT INTO appointment_services(appointment_id,position,service_id,service_name_snapshot) VALUES ($1,0,$2,$3)",
        [appointmentId, serviceId, "Phase2 temporary Service"],
      );
      await tx.commitTransaction();
    } catch (e) {
      await tx.rollbackTransaction();
      throw e;
    } finally {
      await tx.release();
    }
    assert.equal(
      (await req("/services/" + serviceId, "DELETE", undefined, boss)).status,
      409,
    );
    originalCategory = (
      await db.query("SELECT name FROM categories WHERE id='haircut'")
    )[0].name;
    assert.equal(
      (
        await req(
          "/categories",
          "POST",
          { id: "not-an-enum", name: "Invalid" },
          boss,
        )
      ).status,
      400,
    );
    assert.equal(
      (
        await req(
          "/categories",
          "POST",
          { id: "haircut", name: "Duplicate" },
          boss,
        )
      ).status,
      409,
    );
    assert.equal(
      (
        await req(
          "/categories/haircut",
          "PATCH",
          { name: "Phase2 temporary category label" },
          boss,
        )
      ).status,
      200,
    );
    assert.equal(
      (await req("/categories/haircut", "DELETE", undefined, boss)).status,
      409,
    );
    console.log(
      "Live Phase2 passed: forced Manager Branch, role/DTO denial, concurrent approval 200/409, Staff login, reject protected by shift/history, Boss CRUD and settings scope.",
    );
  } finally {
    await db.query("DELETE FROM appointments WHERE id=$1", [appointmentId]);
    await db.query("DELETE FROM staff_shifts WHERE id=$1", [shiftId]);
    if (serviceId)
      await db.query("DELETE FROM services WHERE id=$1", [serviceId]);
    if (originalCategory)
      await db.query("UPDATE categories SET name=$1 WHERE id='haircut'", [
        originalCategory,
      ]);
    for (const id of userIds)
      await db.query("DELETE FROM users WHERE id=$1 AND name LIKE 'Phase2%'", [
        id,
      ]);
    if (branchId) {
      await db.query("DELETE FROM shop_settings WHERE branch_id=$1", [
        branchId,
      ]);
      await db.query("DELETE FROM branches WHERE id=$1", [branchId]);
    }
    await app.close();
  }
})().catch((e) => {
  console.error(
    e.code === "ERR_ASSERTION" ? e.stack : "Phase2 live test failed: " + e.code,
  );
  process.exitCode = 1;
});
