require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Test } = require("@nestjs/testing");
const {
  FirestoreModule,
  FirestoreStore,
} = require("../dist/firestore/firestore.store");
const { UsersModule } = require("../dist/users/users.module");
const { CategoriesModule } = require("../dist/categories/categories.module");
const { ServicesModule } = require("../dist/services/services.module");
const { MemoryFirestore } = require("./support/firestore.cjs");
test("HTTP staff scopes and shared catalog preserve API aliases and exact money", async () => {
  const people = [
    {
      id: "s1",
      name: "A",
      role: "staff",
      branchId: "a",
      isApproved: false,
      specializedCategoryIds: ["hairWash", "haircut"],
    },
    {
      id: "s2",
      name: "B",
      role: "staff",
      branchId: "a",
      isApproved: true,
      specializedCategoryIds: [],
    },
    {
      id: "s3",
      name: "C",
      role: "staff",
      branchId: "b",
      isApproved: false,
      specializedCategoryIds: [],
    },
    { id: "m", role: "manager", branchId: "a" },
  ];
  const catalog = [
    {
      id: "svc1",
      categoryId: "haircut",
      name: "Cut",
      priceVnd: "9007199254740993",
      durationMinutes: 30,
      isActive: true,
    },
  ];
  const module = await Test.createTestingModule({
    imports: [FirestoreModule, UsersModule, CategoriesModule, ServicesModule],
  })
    .overrideProvider(FirestoreStore)
    .useValue(
      new MemoryFirestore({
        users: people,
        categories: [{ id: "haircut", name: "Cut" }],
        services: catalog,
      }),
    )
    .compile();
  const app = module.createNestApplication({ logger: false });
  app.setGlobalPrefix("api");
  app.use((req, res, next) => {
    req.user = { id: "boss", role: "superAdmin", branchId: null };
    next();
  });
  try {
    await app.listen(0, "127.0.0.1");
    const base = await app.getUrl();
    async function get(path) {
      const r = await fetch(base + "/api/" + path);
      assert.equal(r.status, 200);
      return r.json();
    }
    assert.deepEqual(
      (await get("users/pending")).map((r) => r.id),
      ["s1", "s3"],
    );
    assert.deepEqual(
      (await get("users/branch/a")).map((r) => r.id),
      ["s1", "s2"],
    );
    assert.deepEqual((await get("users/branch/a"))[0].specializedCategoryIds, [
      "hairWash",
      "haircut",
    ]);
    assert.deepEqual(await get("users/branch/unknown"), []);
    assert.deepEqual(await get("categories"), [{ id: "haircut", name: "Cut" }]);
    const services = await get("services");
    assert.equal(services[0].price, "9007199254740993");
    assert.equal(services[0].duration, 30);
    assert.equal(services[0].priceVnd, undefined);
  } finally {
    await app.close();
  }
});
