require("reflect-metadata");
const { test } = require("node:test"),
  assert = require("node:assert/strict");
const { plainToInstance } = require("class-transformer"),
  { validate } = require("class-validator");
const { ReviewsService } = require("../dist/reviews/reviews.service");
const { Review } = require("../dist/reviews/review.entity");
const { CreateReviewDto } = require("../dist/reviews/review.dto");
const { Appointment } = require("../dist/appointments/appointment.entity");
const { User } = require("../dist/users/user.entity");
const { Credential } = require("../dist/auth/credential.entity");
const actor = {
  id: "customer",
  role: "customer",
  branchId: null,
  isApproved: true,
  tokenVersion: 1,
};
function fixture(overrides = {}) {
  const { MemoryFirestore } = require("./support/firestore.cjs");
  const db = new MemoryFirestore({
    users: [actor],
    auth_credentials: [{ userId: actor.id, tokenVersion: 1 }],
    appointments: [
      {
        id: "a",
        customerId: actor.id,
        branchId: "b",
        staffId: "s",
        status: "completed",
        ...overrides,
      },
    ],
  });
  return {
    service: new ReviewsService(db),
    get saved() {
      return db.state.reviews;
    },
    get updates() {
      const a = db.state.appointments[0];
      return a.isReviewed ? [{ isReviewed: true, rating: a.rating }] : [];
    },
  };
}

test("review DTO rejects forged target/customer and invalid rating/comment", async () => {
  const valid = { target: "branch", rating: 5 };
  assert.equal(
    (await validate(plainToInstance(CreateReviewDto, valid))).length,
    0,
  );
  for (const extra of [
    { targetId: "else" },
    { customerId: "else" },
    { rating: 0 },
    { rating: 6 },
    { rating: 1.5 },
    { comment: "x".repeat(1001) },
    { target: "boss" },
  ]) {
    assert.ok(
      (
        await validate(
          plainToInstance(CreateReviewDto, { ...valid, ...extra }),
          { whitelist: true, forbidNonWhitelisted: true },
        )
      ).length,
    );
  }
});
test("reviews require customer owner and completed appointment before any insert", async () => {
  for (const role of ["manager", "staff", "superAdmin"]) {
    await assert.rejects(
      fixture().service.create(
        "a",
        { target: "branch", rating: 5 },
        { ...actor, role },
      ),
    );
  }
  for (const override of [
    { customerId: "other" },
    { status: "confirmed" },
    { status: "cancelled" },
    { status: "noShow" },
  ]) {
    const f = fixture(override);
    await assert.rejects(
      f.service.create("a", { target: "branch", rating: 5 }, actor),
    );
    assert.equal(f.saved.length, 0);
  }
});
test("one independent branch and staff review, derived targets and staff metric update", async () => {
  const f = fixture();
  await f.service.create(
    "a",
    { target: "branch", rating: 4, comment: "  Good  " },
    actor,
  );
  await f.service.create("a", { target: "staff", rating: 5 }, actor);
  assert.deepEqual(
    f.saved.map((r) => r.targetId),
    ["b", "s"],
  );
  assert.equal(f.saved[0].comment, "Good");
  assert.deepEqual(f.updates, [{ isReviewed: true, rating: 5 }]);
  await assert.rejects(
    f.service.create("a", { target: "staff", rating: 3 }, actor),
  );
  assert.equal(f.saved.length, 2);
});
