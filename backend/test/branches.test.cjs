require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Test } = require("@nestjs/testing");
const { getRepositoryToken } = require("@nestjs/typeorm");
const { BranchesModule } = require("../dist/branches/branches.module");
const { Branch } = require("../dist/branches/branch.entity");
const { ShopSettings } = require("../dist/branches/shop-settings.entity");
const { validateEnvironment } = require("../dist/config/environment");

test("GET /api/branches returns the database repository rows; prefix is required", async () => {
  const rows = [
    {
      id: "branch-01",
      name: "Cơ sở Cầu Giấy",
      address: "Hà Nội",
      phone: "0901000001",
    },
  ];
  let options;
  const module = await Test.createTestingModule({ imports: [BranchesModule] })
    .overrideProvider(getRepositoryToken(Branch))
    .useValue({
      find: async (query) => {
        options = query;
        return rows;
      },
    })
    .overrideProvider(getRepositoryToken(ShopSettings))
    .useValue({})
    .compile();
  const app = module.createNestApplication({ logger: false });
  app.setGlobalPrefix("api");
  try {
    await app.listen(0, "127.0.0.1");
    const response = await fetch(`${await app.getUrl()}/api/branches`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), rows);
    assert.deepEqual(options.order, { name: "ASC", id: "ASC" });
    assert.equal((await fetch(`${await app.getUrl()}/branches`)).status, 404);
  } finally {
    await app.close();
  }
});

test("database environment validates required variables and numeric ports", () => {
  const env = {
    DB_HOST: "localhost",
    DB_PORT: "5432",
    DB_NAME: "test",
    DB_USER: "test",
    DB_PASSWORD: "secret",
    JWT_SECRET: "test-secret-with-at-least-32-characters",
  };
  assert.equal(validateEnvironment(env).DB_PORT, 5432);
  assert.equal(validateEnvironment(env).PORT, 3000);
  assert.throws(
    () => validateEnvironment({ ...env, DB_PASSWORD: "" }),
    /DB_PASSWORD/,
  );
  assert.throws(
    () => validateEnvironment({ ...env, DB_PORT: "not-a-port" }),
    /DB_PORT/,
  );
});
