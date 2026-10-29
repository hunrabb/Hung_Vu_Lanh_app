require("reflect-metadata");
require("dotenv/config");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { ConfigService } = require("@nestjs/config");
const { Test } = require("@nestjs/testing");
const { AppModule } = require("./dist/app.module");
const {
  FirestoreStore,
  encode,
  collections,
} = require("./dist/firestore/firestore.store");
const { BookingService } = require("./dist/appointments/booking.service");
const {
  AppointmentsService,
} = require("./dist/appointments/appointments.service");
const { AuthService } = require("./dist/auth/auth.service");
const {
  StaffShiftsService,
} = require("./dist/staff-shifts/staff-shifts.service");
const {
  LeaveRequestsService,
} = require("./dist/leave-requests/leave-requests.service");
const { ReviewsService } = require("./dist/reviews/reviews.service");
const { ReportsService } = require("./dist/reports/reports.service");
const { UsersService } = require("./dist/users/users.service");
const { hashPassword } = require("./dist/auth/passwords");
async function main() {
  // The complete AppModule is exercised against a fresh nested namespace only.
  const id = "runtime-" + randomUUID();
  process.env.FIRESTORE_TEST_RUN_ID = id;
  const root = "_test_runs/" + id + "/";
  let app, db, store;
  try {
    const module = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = module.createNestApplication({ logger: false });
    const { ValidationPipe } = require("@nestjs/common");
    app.setGlobalPrefix("api");
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    store = app.get(FirestoreStore);
    db = store.db;
    const date = new Date(Date.now() + 5 * 86400000).toISOString().slice(0, 10),
      startAt = new Date(date + "T01:00:00Z"),
      endAt = new Date(date + "T05:00:00Z");
    const users = [
      { id: "c", name: "Customer", role: "customer", branchId: null },
      { id: "m", name: "Manager", role: "manager", branchId: "b" },
      {
        id: "s",
        name: "Staff",
        role: "staff",
        branchId: "b",
        specializedCategoryIds: ["haircut"],
      },
      { id: "boss", name: "Boss", role: "superAdmin", branchId: null },
    ].map((u) => ({
      ...u,
      email: u.id + "@test.invalid",
      isApproved: true,
      createdAt: new Date(),
      phone: null,
      address: null,
      specializedCategoryIds: u.specializedCategoryIds || [],
    }));
    const hash = await hashPassword("Password123");
    const seed = {
      users,
      auth_credentials: users.map((u) => ({
        userId: u.id,
        passwordHash: hash,
        tokenVersion: 0,
      })),
      branches: [
        {
          id: "b",
          name: "Branch",
          address: "Hanoi",
          phone: "0901234567",
          settings: {
            branchId: "b",
            openingMinute: 480,
            closingMinute: 1200,
            closedDates: [],
            closedWeekdays: [],
          },
        },
      ],
      categories: [{ id: "haircut", name: "Cut" }],
      services: [
        {
          id: "svc",
          name: "Cut",
          categoryId: "haircut",
          priceVnd: "9007199254740993",
          durationMinutes: 30,
          isActive: true,
        },
      ],
      staff_shifts: [
        { id: "shift", branchId: "b", staffId: "s", startAt, endAt },
      ],
    };
    const batch = db.batch();
    for (const [name, rows] of Object.entries(seed))
      for (const r of rows)
        batch.create(
          db
            .collection(root + name)
            .doc(name === "auth_credentials" ? r.userId : r.id),
          encode(r),
        );
    await batch.commit();
    await app.listen(0, "127.0.0.1");
    const base = (await app.getUrl()) + "/api";
    const login = await fetch(base + "/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: "c@test.invalid",
        password: "Password123",
      }),
    });
    assert.equal(login.status, 200);
    const session = await login.json();
    assert.ok(session.accessToken);
    const actor = (id) => ({
      ...users.find((u) => u.id === id),
      tokenVersion: 0,
    });
    const booking = app.get(BookingService),
      dto = {
        branchId: "b",
        staffId: "s",
        serviceIds: ["svc"],
        startAt: startAt.toISOString(),
      };
    const results = await Promise.allSettled([
      booking.book(dto, actor("c")),
      booking.book(dto, actor("c")),
    ]);
    assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal(
      results.find((r) => r.status === "rejected").reason.status,
      409,
    );
    const row = results.find((r) => r.status === "fulfilled").value;
    assert.equal(row.totalPriceVnd, "9007199254740993");
    const persisted = await db.doc(root + "appointments/" + row.id).get();
    assert.equal(persisted.data().totalPriceVnd, 9007199254740993n);
    const list = await fetch(base + "/appointments", {
      headers: { Authorization: "Bearer " + session.accessToken },
    });
    assert.equal(list.status, 200);
    const listed = await list.json();
    assert.equal(listed[0].totalPriceVnd, "9007199254740993");
    assert.equal(listed[0].staffName, "Staff");
    await assert.rejects(
      app.get(StaffShiftsService).edit("shift", undefined, actor("m")),
      { status: 409 },
    );
    await app.get(AppointmentsService).act(row.id, "completed", actor("s"));
    const reviews = app.get(ReviewsService);
    await reviews.create(row.id, { target: "staff", rating: 5 }, actor("c"));
    await assert.rejects(
      reviews.create(row.id, { target: "staff", rating: 4 }, actor("c")),
      { status: 409 },
    );
    const reports = await app
      .get(ReportsService)
      .revenue(actor("m"), { from: date, to: date, page: 1, limit: 50 });
    assert.equal(reports.revenueVnd, "9007199254740993");
    assert.equal(reports.completedCount, 1);
    const leaves = app.get(LeaveRequestsService),
      leave = await leaves.create(
        {
          startAt: new Date(+startAt + 7200000).toISOString(),
          endAt: endAt.toISOString(),
          reason: "Test",
        },
        actor("s"),
      );
    await leaves.decision(leave.id, { status: "approved" }, actor("m"));
    await assert.rejects(
      leaves.decision(leave.id, { status: "rejected" }, actor("m")),
      { status: 409 },
    );
    const usersService = app.get(UsersService),
      pending = await usersService.createStaff(
        {
          name: "Pending",
          email: "pending@test.invalid",
          phone: "0901234567",
          address: "Hanoi",
          specializedCategoryIds: ["haircut"],
        },
        actor("m"),
      );
    await usersService.approve(pending.id, "Password123", actor("boss"));
    const auth = app.get(AuthService),
      dupes = await Promise.allSettled([
        auth.register({
          name: "One",
          email: "duplicate@test.invalid",
          password: "Password123",
        }),
        auth.register({
          name: "Two",
          email: "duplicate@test.invalid",
          password: "Password123",
        }),
      ]);
    assert.equal(dupes.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal(dupes.find((r) => r.status === "rejected").reason.status, 409);
    await auth.logout(actor("c"));
    const revoked = await fetch(base + "/auth/me", {
      headers: { Authorization: "Bearer " + session.accessToken },
    });
    assert.equal(revoked.status, 401);
    console.log(
      "PASS: full NestJS HTTP/JWT; Firestore int64; concurrent booking/email; shift protection; reviews; leave history; approval; reports; token revocation.",
    );
  } finally {
    if (db) {
      for (const name of [...collections, "_runtime"]) {
        const rows = await db.collection(root + name).get();
        if (rows.size) {
          const batch = db.batch();
          for (const doc of rows.docs) batch.delete(doc.ref);
          await batch.commit();
        }
      }
      console.log("Isolated test documents removed.");
    }
    if (app) await app.close();
  }
}
main().catch((error) => {
  console.error("Live Firestore test failed: " + (error.code || error.message));
  console.error(
    String(error.stack)
      .split("\n")
      .filter((line) => line.trim().startsWith("at "))
      .join("\n"),
  );
  process.exitCode = 1;
});
