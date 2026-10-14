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
  const appointment = {
    id: "a",
    customerId: actor.id,
    branchId: "b",
    staffId: "s",
    status: "completed",
    ...overrides,
  };
  const saved = [],
    updates = [];
  const manager = {
    findOne: async (entity, options) =>
      entity === User
        ? actor
        : entity === Credential
          ? { tokenVersion: 1 }
          : entity === Appointment
            ? appointment
            : saved.find((r) => r.target === options.where.target),
    create: (_, value) => value,
    insert: async (_, value) => saved.push(value),
    update: async (_, id, value) => updates.push(value),
  };
  return {
    service: new ReviewsService({
      manager: { connection: { transaction: (work) => work(manager) } },
    }),
    saved,
    updates,
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
