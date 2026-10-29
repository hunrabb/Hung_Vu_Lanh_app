require("reflect-metadata");
const { test } = require("node:test"),
  assert = require("node:assert/strict");
const { MemoryFirestore } = require("./support/firestore.cjs");
const { BookingService } = require("../dist/appointments/booking.service");
const {
  AppointmentsService,
} = require("../dist/appointments/appointments.service");
const {
  StaffShiftsService,
} = require("../dist/staff-shifts/staff-shifts.service");
const {
  LeaveRequestsService,
} = require("../dist/leave-requests/leave-requests.service");
const { UsersService } = require("../dist/users/users.service");
const { ServicesService } = require("../dist/services/services.service");
const { BranchesService } = require("../dist/branches/branches.service");
const { ReportsService } = require("../dist/reports/reports.service");
const { AuthService } = require("../dist/auth/auth.service");
const { decode, encode, wire } = require("../dist/firestore/firestore.store");
const { Timestamp } = require("firebase-admin/firestore");
function fixture() {
  const date = new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 10),
    startAt = new Date(date + "T01:00:00Z"),
    endAt = new Date(date + "T05:00:00Z");
  const users = [
    {
      id: "c",
      name: "Customer",
      email: "c@example.com",
      role: "customer",
      branchId: null,
    },
    {
      id: "m",
      name: "Manager",
      email: "m@example.com",
      role: "manager",
      branchId: "b",
    },
    {
      id: "s",
      name: "Staff",
      email: "s@example.com",
      role: "staff",
      branchId: "b",
      specializedCategoryIds: ["haircut"],
    },
    {
      id: "boss",
      name: "Boss",
      email: "boss@example.com",
      role: "superAdmin",
      branchId: null,
    },
  ].map((u) => ({ ...u, isApproved: true, createdAt: new Date() }));
  const db = new MemoryFirestore({
    users,
    auth_credentials: users.map((u) => ({
      userId: u.id,
      passwordHash: "hash",
      tokenVersion: 0,
    })),
    branches: [
      {
        id: "b",
        name: "Branch",
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
        isActive: true,
        priceVnd: "9007199254740993",
        durationMinutes: 30,
      },
    ],
    staff_shifts: [
      { id: "shift", staffId: "s", branchId: "b", startAt, endAt },
    ],
  });
  const actor = (id) => ({
    ...db.state.users.find((u) => u.id === id),
    tokenVersion: 0,
  });
  return {
    db,
    actor,
    date,
    startAt,
    endAt,
    booking: {
      branchId: "b",
      staffId: "s",
      serviceIds: ["svc"],
      startAt: startAt.toISOString(),
    },
  };
}
test("Firestore mappings preserve int64, UTC Timestamp, numeric arrays and API aliases", () => {
  const r = decode({
    priceVnd: 9007199254740993n,
    durationMinutes: 30n,
    closedWeekdays: [1n, 7n],
    createdAt: Timestamp.fromMillis(1000),
    tokenVersion: 3n,
  });
  assert.equal(r.priceVnd, "9007199254740993");
  assert.equal(r.durationMinutes, 30);
  assert.deepEqual(r.closedWeekdays, [1, 7]);
  assert.equal(+r.createdAt, 1000);
  assert.equal(r.tokenVersion, 3);
  assert.equal(encode(r).priceVnd, 9007199254740993n);
  assert.equal(wire("services", r).price, "9007199254740993");
  assert.equal(wire("services", r).duration, 30);
});
test("two competing bookings produce one winner and a conflict; snapshots and independent hide survive", async () => {
  const f = fixture(),
    booking = new BookingService(f.db),
    ops = new AppointmentsService(f.db);
  const results = await Promise.allSettled([
    booking.book(f.booking, f.actor("c")),
    booking.book(f.booking, f.actor("c")),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.find((r) => r.status === "rejected").reason.status, 409);
  const row = f.db.state.appointments[0];
  assert.equal(row.totalPriceVnd, "9007199254740993");
  assert.equal(row.services[0].serviceNameSnapshot, "Cut");
  await assert.rejects(ops.act(row.id, "completed", f.actor("c")), {
    status: 403,
  });
  await ops.act(row.id, "completed", f.actor("s"));
  await ops.act(row.id, "hideCustomer", f.actor("c"));
  assert.equal(
    (await ops.list({ page: 1, limit: 50 }, f.actor("c"))).length,
    0,
  );
  assert.equal(
    (await ops.list({ page: 1, limit: 50 }, f.actor("s"))).length,
    1,
  );
  await assert.rejects(
    new StaffShiftsService(f.db).edit("shift", undefined, f.actor("m")),
    { status: 409 },
  );
});
test("calendar checks specialization, inactive services, settings, absence and immutable leave decisions", async () => {
  const f = fixture(),
    booking = new BookingService(f.db),
    leaves = new LeaveRequestsService(f.db);
  const row = await leaves.create(
    {
      startAt: f.startAt.toISOString(),
      endAt: new Date(+f.startAt + 3600000).toISOString(),
      reason: "Medical",
    },
    f.actor("s"),
  );
  await assert.rejects(
    leaves.create(
      {
        startAt: f.startAt.toISOString(),
        endAt: f.endAt.toISOString(),
        reason: "Other",
      },
      f.actor("s"),
    ),
    { status: 409 },
  );
  const approved = await leaves.decision(
    row.id,
    { status: "approved", note: "OK" },
    f.actor("m"),
  );
  assert.equal(approved.reviewedByName, "Manager");
  assert.equal(approved.reviewedBranchName, "Branch");
  assert.ok(approved.reviewedAt instanceof Date);
  await assert.rejects(
    leaves.decision(row.id, { status: "rejected" }, f.actor("boss")),
    { status: 409 },
  );
  await assert.rejects(booking.book(f.booking, f.actor("c")), { status: 409 });
  f.db.state.services[0].isActive = false;
  await assert.rejects(booking.available({ ...f.booking, date: f.date }));
  f.db.state.services[0].isActive = true;
  f.db.state.users.find((u) => u.id === "s").specializedCategoryIds = [];
  await assert.rejects(booking.book(f.booking, f.actor("c")), { status: 400 });
});
test("parallel duplicate email registration is atomic and logout revokes prior JWT version", async () => {
  const f = fixture(),
    auth = new AuthService(f.db, { signAsync: async (p) => JSON.stringify(p) }),
    dto = { name: "New", email: "new@example.com", password: "Password123" };
  const results = await Promise.allSettled([
    auth.register(dto),
    auth.register(dto),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.find((r) => r.status === "rejected").reason.status, 409);
  await auth.logout(f.actor("c"));
  await assert.rejects(
    auth.validateToken({ sub: "c", role: "customer", branchId: null, ver: 0 }),
    { status: 401 },
  );
  await assert.rejects(
    auth.updateProfile(f.actor("m"), {
      name: "M",
      email: "c@example.com",
      phone: "",
      address: "",
    }),
    { status: 409 },
  );
});
test("staff approval, referential deletion and role/branch guards remain atomic", async () => {
  const f = fixture(),
    users = new UsersService(f.db),
    branches = new BranchesService(f.db),
    catalog = new ServicesService(f.db);
  const pending = await users.createStaff(
    {
      name: "Pending",
      email: "p@example.com",
      phone: "0901234567",
      address: "Hanoi",
      specializedCategoryIds: ["haircut"],
    },
    f.actor("m"),
  );
  assert.equal(pending.isApproved, false);
  await users.approve(pending.id, "Password123", f.actor("boss"));
  assert.equal(
    f.db.state.auth_credentials.filter((c) => c.userId === pending.id).length,
    1,
  );
  await assert.rejects(
    users.approve(pending.id, "Password123", f.actor("boss")),
    { status: 409 },
  );
  await assert.rejects(users.rejectPending(pending.id, f.actor("boss")), {
    status: 409,
  });
  await assert.rejects(branches.delete("b", f.actor("boss")), { status: 409 });
  await new BookingService(f.db).book(f.booking, f.actor("c"));
  await assert.rejects(catalog.delete("svc", f.actor("boss")), { status: 409 });
  await assert.rejects(
    branches.settings("b", { closingMinute: 400 }, f.actor("m")),
    { status: 400 },
  );
  assert.equal(f.db.state.branches[0].settings.closingMinute, 1200);
});
test("completed-only reports preserve exact money, service cardinality, scope and 30 percent floor", async () => {
  const f = fixture(),
    r = await new BookingService(f.db).book(f.booking, f.actor("c"));
  f.db.state.appointments[0].status = "completed";
  f.db.state.appointments[0].services.push({ ...r.services[0], position: 1 });
  f.db.state.appointments.push({
    ...structuredClone(f.db.state.appointments[0]),
    id: "cancelled",
    status: "cancelled",
  });
  const reports = new ReportsService(f.db),
    q = { from: f.date, to: f.date, page: 1, limit: 50 };
  const revenue = await reports.revenue(f.actor("m"), q);
  assert.equal(revenue.revenueVnd, "9007199254740993");
  assert.equal(revenue.completedCount, 1);
  assert.equal(revenue.appointmentCount, 2);
  assert.equal(revenue.customerCount, 1);
  const commission = await reports.commissions(f.actor("boss"), q);
  assert.equal(
    commission.staff[0].commissionVnd,
    ((9007199254740993n * 30n) / 100n).toString(),
  );
  assert.equal(
    (await reports.profileStats(f.actor("s"), q)).registeredCustomerCount,
    1,
  );
});
module.exports = { fixture };
