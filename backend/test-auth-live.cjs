require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { NestFactory } = require("@nestjs/core");
const { ValidationPipe } = require("@nestjs/common");
const { DataSource } = require("typeorm");
const { AppModule } = require("./dist/app.module");
async function start() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix("api");
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  await app.listen(0, "127.0.0.1");
  return app;
}
async function request(base, path, method = "GET", body, token) {
  const r = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: "Bearer " + token } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  return { status: r.status, body: await r.json() };
}
const passFor = (row) =>
  row.role === "superAdmin"
    ? "boss123"
    : row.role === "manager"
      ? row.id === "admin-01"
        ? "admin123"
        : "manager123"
      : row.role === "staff"
        ? "staff123"
        : "customer123";
(async () => {
  let app = await start();
  let db = app.get(DataSource);
  let base = await app.getUrl();
  try {
    const approved = await db.query(
      "SELECT id,email,role FROM users WHERE id IN ('boss-01','admin-01','manager-02','manager-03','manager-04','staff-01','staff-02','staff-03','staff-04','staff-05','staff-07','staff-08','staff-09','staff-10','staff-11','customer-01','customer-02','customer-03') AND is_approved",
    );
    assert.equal(approved.length, 18);
    for (const row of approved) {
      const login = await request(base, "/api/auth/login", "POST", {
        email: row.email,
        password: passFor(row),
      });
      assert.equal(login.status, 200);
    }
    const legacy = await db.query(
      "SELECT count(*) FROM auth_credentials c WHERE c.user_id=ANY($1::text[]) AND c.password_hash LIKE '$scrypt$%'",
      [approved.map((u) => u.id)],
    );
    assert.equal(legacy[0].count, "0");
    console.log("18 approved seed accounts logged in and migrated to bcrypt.");
  } finally {
    await app.close();
  }
  app = await start();
  db = app.get(DataSource);
  base = await app.getUrl();
  let temporaryId;
  try {
    const login = async (email, password) => {
      const r = await request(base, "/api/auth/login", "POST", {
        email,
        password,
      });
      assert.equal(r.status, 200);
      return r.body.accessToken;
    };
    assert.equal((await request(base, "/api/users/pending")).status, 401);
    const boss = await login("boss@example.com", "boss123");
    assert.equal(
      (await request(base, "/api/users/pending", "GET", undefined, boss)).body
        .length,
      5,
    );
    const manager = await login("admin@example.com", "admin123");
    assert.equal(
      (await request(base, "/api/users/pending", "GET", undefined, manager))
        .status,
      403,
    );
    assert.equal(
      (
        await request(
          base,
          "/api/users/branch/branch-01",
          "GET",
          undefined,
          manager,
        )
      ).status,
      200,
    );
    assert.equal(
      (
        await request(
          base,
          "/api/users/branch/branch-02",
          "GET",
          undefined,
          manager,
        )
      ).status,
      403,
    );
    assert.equal(
      (
        await request(base, "/api/auth/login", "POST", {
          email: "pending@example.com",
          password: "staff123",
        })
      ).status,
      401,
    );
    assert.equal(
      (
        await request(base, "/api/auth/register", "POST", {
          email: "blocked@example.com",
          name: "Blocked",
          password: "Customer123!",
          role: "superAdmin",
        })
      ).status,
      400,
    );
    const email = "auth-smoke-" + crypto.randomUUID() + "@example.com";
    const registered = await request(base, "/api/auth/register", "POST", {
      email,
      name: "Auth smoke temporary",
      password: "Customer123!",
    });
    assert.equal(registered.status, 201);
    temporaryId = registered.body.user.id;
    assert.equal(registered.body.user.role, "customer");
    assert.equal(registered.body.user.branchId, null);
    let token = registered.body.accessToken;
    assert.equal(
      (await request(base, "/api/auth/me", "GET", undefined, token)).body.id,
      temporaryId,
    );
    assert.equal(
      (
        await request(
          base,
          "/api/auth/password",
          "PATCH",
          { oldPassword: "wrong", newPassword: "Customer456!" },
          token,
        )
      ).status,
      401,
    );
    assert.equal(
      (
        await request(
          base,
          "/api/auth/password",
          "PATCH",
          { oldPassword: "Customer123!", newPassword: "Customer456!" },
          token,
        )
      ).status,
      200,
    );
    assert.equal(
      (await request(base, "/api/auth/me", "GET", undefined, token)).status,
      401,
    );
    assert.equal(
      (
        await request(base, "/api/auth/login", "POST", {
          email,
          password: "Customer123!",
        })
      ).status,
      401,
    );
    token = await login(email, "Customer456!");
    const second = await login(email, "Customer456!");
    assert.equal(
      (await request(base, "/api/auth/logout", "POST", undefined, token))
        .status,
      200,
    );
    assert.equal(
      (await request(base, "/api/auth/me", "GET", undefined, second)).status,
      401,
    );
    console.log(
      "Live Auth: register/login/me/password/logout, token revocation, Boss role and Manager branch isolation passed.",
    );
  } finally {
    if (temporaryId)
      await db.query(
        "DELETE FROM users WHERE id=$1 AND role='customer' AND name='Auth smoke temporary'",
        [temporaryId],
      );
    await app.close();
  }
})().catch(() => {
  console.error("Live auth test failed (tokens/passwords omitted)");
  process.exitCode = 1;
});
