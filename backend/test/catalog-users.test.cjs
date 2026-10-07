require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Test } = require("@nestjs/testing");
const { getRepositoryToken } = require("@nestjs/typeorm");
const { DataSource } = require("typeorm");
const { UsersModule } = require("../dist/users/users.module");
const { User } = require("../dist/users/user.entity");
const {
  StaffSpecialization,
} = require("../dist/users/staff-specialization.entity");
const { Credential } = require("../dist/auth/credential.entity");
const { CategoriesModule } = require("../dist/categories/categories.module");
const { Category } = require("../dist/categories/category.entity");
const { ServicesModule } = require("../dist/services/services.module");
const { Service } = require("../dist/services/service.entity");

test("new read routes filter Staff correctly and return the shared catalog", async () => {
  const people = [
    { id: "s1", role: "staff", branchId: "a", isApproved: false },
    { id: "s2", role: "staff", branchId: "a", isApproved: true },
    { id: "s3", role: "staff", branchId: "b", isApproved: false },
    { id: "m1", role: "manager", branchId: "a", isApproved: false },
    { id: "c1", role: "customer", branchId: null, isApproved: true },
  ];
  const catalog = [
    {
      id: "svc1",
      categoryId: "haircut",
      name: "Cut",
      price: "9007199254740993",
      duration: 30,
      isActive: true,
    },
  ];
  const module = await Test.createTestingModule({
    imports: [UsersModule, CategoriesModule, ServicesModule],
  })
    .overrideProvider(getRepositoryToken(User))
    .useValue({
      find: async ({ where }) =>
        people.filter((p) =>
          Object.entries(where).every(([k, v]) => p[k] === v),
        ),
    })
    .overrideProvider(getRepositoryToken(Category))
    .useValue({ find: async () => [{ id: "haircut", name: "Cắt tóc" }] })
    .overrideProvider(getRepositoryToken(Service))
    .useValue({ find: async () => catalog })
    .overrideProvider(getRepositoryToken(StaffSpecialization))
    .useValue({})
    .overrideProvider(getRepositoryToken(Credential))
    .useValue({})
    .compile();
  const app = module.createNestApplication({ logger: false });
  app.setGlobalPrefix("api");
  app.use((req, _res, next) => {
    req.user = { id: "boss-test", role: "superAdmin", branchId: null };
    next();
  });
  try {
    await app.listen(0, "127.0.0.1");
    const base = await app.getUrl();
    async function get(path) {
      const r = await fetch(base + path);
      assert.equal(r.status, 200);
      return r.json();
    }
    assert.deepEqual(
      (await get("/api/users/pending")).map((p) => p.id),
      ["s1", "s3"],
    );
    assert.deepEqual(
      (await get("/api/users/branch/a")).map((p) => p.id),
      ["s1", "s2"],
    );
    assert.deepEqual(await get("/api/users/branch/unknown"), []);
    assert.deepEqual(await get("/api/categories"), [
      { id: "haircut", name: "Cắt tóc" },
    ]);
    assert.deepEqual(await get("/api/services"), catalog);
  } finally {
    await app.close();
  }
});

test("entity mappings match the inspected PostgreSQL schema without schema synchronization", async () => {
  const dataSource = new DataSource({
    type: "postgres",
    entities: [User, Category, Service],
    synchronize: false,
  });
  await dataSource.buildMetadatas();
  const column = (entity, name) =>
    dataSource.getMetadata(entity).findColumnWithPropertyName(name);
  assert.equal(column(User, "branchId").databaseName, "branch_id");
  assert.equal(column(User, "isApproved").databaseName, "is_approved");
  assert.equal(column(Service, "price").databaseName, "price_vnd");
  assert.equal(column(Service, "price").type, "bigint");
  assert.equal(column(Service, "duration").databaseName, "duration_minutes");
  assert.equal(dataSource.options.synchronize, false);
});
