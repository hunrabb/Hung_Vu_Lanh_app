require("reflect-metadata");
const { test } = require("node:test"),
  assert = require("node:assert/strict");
const { plainToInstance } = require("class-transformer"),
  { validate } = require("class-validator");
const {
  calculateSlots,
  freeSpans,
  hanoiDay,
} = require("../dist/appointments/slot-engine");
const {
  CreateBookingDto,
  WalkInDto,
  AvailableSlotsDto,
} = require("../dist/appointments/appointment.dto");
const {
  BookingService,
  retryTransaction,
} = require("../dist/appointments/booking.service");
const {
  AppointmentsService,
} = require("../dist/appointments/appointments.service");
const minute = 60000;
test("Hanoi day uses UTC+7, ISO weekday and rejects nonexistent dates", () => {
  assert.equal(
    new Date(hanoiDay("2031-01-05").start).toISOString(),
    "2031-01-04T17:00:00.000Z",
  );
  assert.equal(hanoiDay("2031-01-05").weekday, 7);
  assert.throws(() => hanoiDay("2031-02-30"));
  assert.throws(() => hanoiDay("2031-2-3"));
  assert.throws(() => hanoiDay("0000-01-01"));
});
test("slots intersect opening hours and shifts, preserve breaks, and require a shift", () => {
  const open = { start: 8 * 60 * minute, end: 20 * 60 * minute };
  const shifts = [
    { start: 7 * 60 * minute, end: 12 * 60 * minute },
    { start: 13 * 60 * minute, end: 22 * 60 * minute },
  ];
  const result = calculateSlots(open, shifts, [], 90, 0);
  assert.ok(result.slots.length);
  for (const slot of result.slots) {
    const start = +new Date(slot.startAt),
      end = +new Date(slot.endAt);
    assert.ok(start >= open.start && end <= open.end);
    assert.ok(end <= 12 * 60 * minute || start >= 13 * 60 * minute);
  }
  assert.deepEqual(calculateSlots(open, [], [], 30, 0).slots, []);
  assert.deepEqual(calculateSlots(open, shifts, [], 1440, 0).slots, []);
});
test("continuous adjacent/overlapping shifts merge; busy intervals use half-open bounds", () => {
  const result = calculateSlots(
    { start: 0, end: 180 * minute },
    [
      { start: 0, end: 60 * minute },
      { start: 60 * minute, end: 180 * minute },
    ],
    [{ start: 60 * minute, end: 90 * minute }],
    60,
    -1,
  );
  assert.deepEqual(
    result.slots.map((s) => +new Date(s.startAt)),
    [0, 90 * minute],
  );
  assert.deepEqual(
    freeSpans(
      [{ start: 0, end: 10 }],
      [
        { start: -5, end: 0 },
        { start: 10, end: 20 },
      ],
    ),
    [{ start: 0, end: 10 }],
  );
  assert.deepEqual(
    freeSpans(
      [{ start: 0, end: 10 }],
      [
        { start: 2, end: 4 },
        { start: 3, end: 8 },
      ],
    ),
    [
      { start: 0, end: 2 },
      { start: 8, end: 10 },
    ],
  );
});
test("past slots disappear and total duration fits inside each remaining interval", () => {
  const result = calculateSlots(
    { start: 0, end: 180 * minute },
    [{ start: 0, end: 180 * minute }],
    [{ start: 90 * minute, end: 120 * minute }],
    30,
    30 * minute,
  );
  assert.deepEqual(
    result.slots.map((s) => +new Date(s.startAt)),
    [60 * minute, 120 * minute, 150 * minute],
  );
});
test("DTO rejects forged identity/money, duplicate services and walk-in branch injection", async () => {
  const body = {
    branchId: "A",
    staffId: "S",
    serviceIds: ["one"],
    startAt: "2031-01-01T08:00:00+07:00",
  };
  assert.equal(
    (
      await validate(plainToInstance(CreateBookingDto, body), {
        whitelist: true,
        forbidNonWhitelisted: true,
      })
    ).length,
    0,
  );
  for (const extra of [
    { customerId: "victim" },
    { totalPriceVnd: "1" },
    { duration: 1 },
    { serviceIds: ["one", "one"] },
    { startAt: null },
    { serviceIds: [] },
  ])
    assert.ok(
      (
        await validate(
          plainToInstance(CreateBookingDto, { ...body, ...extra }),
          { whitelist: true, forbidNonWhitelisted: true },
        )
      ).length,
    );
  assert.ok(
    (
      await validate(
        plainToInstance(WalkInDto, { ...body, customerName: "Guest" }),
        { whitelist: true, forbidNonWhitelisted: true },
      )
    ).length,
  );
  assert.deepEqual(
    plainToInstance(AvailableSlotsDto, { serviceIds: "one,two" }).serviceIds,
    ["one", "two"],
  );
});
test("booking and transitions enforce roles and ownership before writes", async () => {
  const booking = new BookingService({});
  assert.throws(() => booking.book({}, { role: "staff" }));
  assert.throws(() => booking.book({}, { role: "customer" }, true));
  const { MemoryFirestore } = require("./support/firestore.cjs");
  const actors = [
    {
      id: "m",
      role: "manager",
      branchId: "else",
      tokenVersion: 0,
      isApproved: true,
    },
    {
      id: "else",
      role: "customer",
      branchId: null,
      tokenVersion: 0,
      isApproved: true,
    },
    {
      id: "worker",
      role: "staff",
      branchId: "B",
      tokenVersion: 0,
      isApproved: true,
    },
  ];
  const ops = new AppointmentsService(
    new MemoryFirestore({
      users: actors,
      auth_credentials: actors.map((u) => ({ userId: u.id, tokenVersion: 0 })),
      appointments: [{ id: "A", branchId: "B", staffId: "S", customerId: "C" }],
    }),
  );
  await assert.rejects(
    ops.act("A", "completed", {
      id: "m",
      role: "manager",
      branchId: "else",
      tokenVersion: 0,
    }),
  );
  await assert.rejects(
    ops.act("A", "cancel", {
      role: "customer",
      id: "else",
      branchId: null,
      tokenVersion: 0,
    }),
  );
  await assert.rejects(
    ops.act("A", "completed", {
      role: "staff",
      id: "worker",
      branchId: "B",
      tokenVersion: 0,
    }),
  );
  await assert.rejects(
    ops.list({ branchId: "other" }, { role: "manager", branchId: "B" }),
  );
});
