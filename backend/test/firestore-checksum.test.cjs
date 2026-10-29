const { test } = require("node:test"),
  assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const { checksum, verifyCollections } = require("../firestore-checksum.cjs");
const { ownsFixture, cleanup } = require("../cleanup-flutter-fixture.cjs");
test("Firestore checksum preserves native timestamp precision, map order and exact int64", async () => {
  const time = new Timestamp(1000, 123456000),
    original = [
      {
        id: "x",
        data: { priceVnd: 9007199254740993n, at: time, nested: { a: 1, b: 2 } },
      },
    ];
  const actual = [
    {
      id: "x",
      data: { nested: { b: 2n, a: 1n }, at: time, priceVnd: 9007199254740993n },
    },
  ];
  assert.equal(checksum(original), checksum(actual));
  const db = {
    collection: () => ({
      get: async () => ({
        size: 1,
        docs: actual.map((d) => ({ id: d.id, data: () => d.data })),
      }),
    }),
  };
  const summary = [
    { name: "services", count: 1n, checksum: checksum(original) },
  ];
  await verifyCollections(db, summary);
  actual[0].data.priceVnd++;
  await assert.rejects(verifyCollections(db, summary), /Verification failed/);
  assert.notEqual(
    checksum(original),
    checksum([
      {
        id: "x",
        data: { ...original[0].data, at: new Timestamp(1000, 123457000) },
      },
    ]),
  );
});
test("Flutter fixture cleanup refuses unrelated users and unexpected appointments before any writes", async () => {
  const user = {
    id: "fixture",
    name: "Phase6 Flutter fixture",
    email: "phase6-123@example.com",
  };
  assert.ok(ownsFixture(user, "fixture"));
  assert.equal(ownsFixture({ ...user, name: "Real user" }, "fixture"), false);
  assert.equal(ownsFixture(user, "other"), false);
  let writes = 0,
    owned = false,
    unexpected = false;
  const ref = {};
  const db = {
    doc: () => ref,
    collection: (name) => ({
      doc: () => (name === "users" ? { user: true } : ref),
      where: () => ({ query: name }),
    }),
    runTransaction: (work) =>
      work({
        get: async (ref) =>
          ref.user
            ? {
                exists: true,
                data: () => (owned ? user : { ...user, name: "Real user" }),
              }
            : ref.query
              ? {
                  docs:
                    unexpected && ref.query === "appointments"
                      ? [{ id: "unexpected" }]
                      : [],
                }
              : {},
        delete: () => writes++,
        set: () => writes++,
      }),
  };
  await assert.rejects(cleanup(db, "fixture", []), /unowned/);
  assert.equal(writes, 0);
  owned = true;
  unexpected = true;
  await assert.rejects(cleanup(db, "fixture", []), /unexpected appointments/);
  assert.equal(writes, 0);
});
