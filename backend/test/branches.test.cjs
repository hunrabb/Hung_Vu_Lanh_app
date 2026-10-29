require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { Test } = require("@nestjs/testing");
const {
  FirestoreModule,
  FirestoreStore,
} = require("../dist/firestore/firestore.store");
const { BranchesModule } = require("../dist/branches/branches.module");
const { validateEnvironment } = require("../dist/config/environment");
const { MemoryFirestore } = require("./support/firestore.cjs");
test("GET /api/branches returns Firestore rows without embedded private settings; prefix required", async () => {
  const row = {
    id: "branch-01",
    name: "Hanoi",
    address: "Hanoi",
    phone: "0901000001",
  };
  const module = await Test.createTestingModule({
    imports: [FirestoreModule, BranchesModule],
  })
    .overrideProvider(FirestoreStore)
    .useValue(
      new MemoryFirestore({
        branches: [{ ...row, settings: { openingMinute: 480 } }],
      }),
    )
    .compile();
  const app = module.createNestApplication({ logger: false });
  app.setGlobalPrefix("api");
  try {
    await app.listen(0, "127.0.0.1");
    const url = await app.getUrl();
    const r = await fetch(url + "/api/branches");
    assert.equal(r.status, 200);
    assert.deepEqual(await r.json(), [row]);
    assert.equal((await fetch(url + "/branches")).status, 404);
  } finally {
    await app.close();
  }
});
test("Firestore environment requires project/database and validates JWT and port without PostgreSQL", () => {
  const env = {
    FIREBASE_PROJECT_ID: "demo-test",
    FIRESTORE_DATABASE_ID: "(default)",
    JWT_SECRET: "test-secret-with-at-least-32-characters",
  };
  assert.equal(validateEnvironment(env).PORT, 3000);
  for (const changes of [
    { FIREBASE_PROJECT_ID: "" },
    { FIRESTORE_DATABASE_ID: "" },
    { JWT_SECRET: "short" },
    { PORT: "bad" },
    { PORT: 65536 },
    { JWT_TTL_SECONDS: 1 },
  ])
    assert.throws(() => validateEnvironment({ ...env, ...changes }));
});
