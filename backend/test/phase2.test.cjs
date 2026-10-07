require("reflect-metadata");
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { plainToInstance } = require("class-transformer");
const { validate } = require("class-validator");
const { CreateStaffDto, UpdateStaffDto } = require("../dist/users/staff.dto");
const { CreateServiceDto } = require("../dist/services/service.dto");
const { UpdateSettingsDto } = require("../dist/branches/branch.dto");
const { UsersService } = require("../dist/users/users.service");
const { BranchesService } = require("../dist/branches/branches.service");
const { CategoriesService } = require("../dist/categories/categories.service");
const { ServicesService } = require("../dist/services/services.service");
async function errors(type, body) {
  return validate(plainToInstance(type, body), {
    whitelist: true,
    forbidNonWhitelisted: true,
  });
}
test("Phase2 DTOs reject actor/approval/password injection, null updates and invalid money/dates", async () => {
  const staff = {
    name: "Staff",
    email: " STAFF@EXAMPLE.COM ",
    phone: "0901234567",
    address: "Hà Nội",
    specializedCategoryIds: ["haircut"],
  };
  assert.equal((await errors(CreateStaffDto, staff)).length, 0);
  assert.equal(
    plainToInstance(CreateStaffDto, staff).email,
    "staff@example.com",
  );
  for (const extra of [
    { branchId: "b" },
    { role: "superAdmin" },
    { isApproved: true },
    { password: "Injected123" },
  ])
    assert.ok((await errors(CreateStaffDto, { ...staff, ...extra })).length);
  assert.ok((await errors(UpdateStaffDto, { name: null })).length);
  assert.ok(
    (
      await errors(CreateStaffDto, {
        ...staff,
        specializedCategoryIds: ["haircut", "haircut"],
      })
    ).length,
  );
  const service = {
    name: "Service",
    categoryId: "haircut",
    price: "9007199254740993",
    duration: 30,
  };
  assert.equal((await errors(CreateServiceDto, service)).length, 0);
  for (const price of [-1, 1.5, 9007199254740992, "9223372036854775808"])
    assert.ok((await errors(CreateServiceDto, { ...service, price })).length);
  assert.ok(
    (await errors(UpdateSettingsDto, { closedDates: ["2030-02-30"] })).length,
  );
  assert.ok((await errors(UpdateSettingsDto, { closedWeekdays: [8] })).length);
});
test("write services deny roles before touching a repository", async () => {
  const manager = { id: "m", role: "manager", branchId: "a", tokenVersion: 0 };
  const boss = { id: "b", role: "superAdmin", branchId: null, tokenVersion: 0 };
  const users = new UsersService({});
  await assert.rejects(users.createStaff({}, boss), { status: 403 });
  await assert.rejects(users.approve("staff", "Password123", manager), {
    status: 403,
  });
  for (const Service of [BranchesService, CategoriesService, ServicesService])
    await assert.rejects(new Service({}).create({}, manager), { status: 403 });
});
