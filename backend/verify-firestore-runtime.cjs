require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict");
const { NestFactory } = require("@nestjs/core");
const { AppModule } = require("./dist/app.module");
const { FirestoreStore } = require("./dist/firestore/firestore.store");
const { verifyCollections } = require("./firestore-checksum.cjs");
async function main() {
  if (process.env.FIRESTORE_TEST_RUN_ID)
    throw new Error(
      "Unset FIRESTORE_TEST_RUN_ID for production read-only verification",
    );
  const app = await NestFactory.create(AppModule, { logger: false });
  try {
    const store = app.get(FirestoreStore),
      record = await store.db.doc("_migrations/aiven-nosql-v1").get();
    assert.ok(record.exists, "Migration manifest missing");
    await verifyCollections(store.db, record.data().collections);
    console.log(
      "PASS: all production document IDs, counts and content match the imported snapshot; no production writes.",
    );
    app.setGlobalPrefix("api");
    await app.listen(0, "127.0.0.1");
    const base = (await app.getUrl()) + "/api";
    for (const [path, count] of [
      ["branches", 4],
      ["services", 20],
      ["categories", 6],
    ]) {
      const r = await fetch(base + "/" + path);
      assert.equal(r.status, 200);
      const rows = await r.json();
      assert.equal(rows.length, count);
      if (path === "services") {
        assert.equal(typeof rows[0].price, "string");
        assert.equal(typeof rows[0].duration, "number");
      }
      console.log("PASS: GET /api/" + path + " => " + rows.length + " rows");
    }
  } finally {
    await app.close();
  }
}
main().catch((error) => {
  console.error(
    "Read-only verification failed: " + (error.code || error.message),
  );
  process.exitCode = 1;
});
