import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { EntityManager } from "typeorm";
import { Actor } from "../auth/auth.decorators";
import { User } from "../users/user.entity";
import { ShopSettings } from "../branches/shop-settings.entity";
import { requireRole } from "./mutations";

export function branchScope(actor: Actor, branchId: string) {
  requireRole(actor, ["superAdmin", "manager"]);
  if (actor.role === "manager" && actor.branchId !== branchId)
    throw new ForbiddenException("Branch access denied");
}
export function interval(start: string | Date, end: string | Date) {
  const a = new Date(start),
    b = new Date(end);
  if (!Number.isFinite(+a) || !Number.isFinite(+b) || b <= a)
    throw new BadRequestException("endAt must follow startAt");
  if (+b - +a > 31 * 86400000)
    throw new BadRequestException("Interval cannot exceed 31 days");
  return { startAt: a, endAt: b };
}
// Calendar writers/booking must always acquire settings -> Staff -> record locks.
export async function lockCalendar(
  manager: EntityManager,
  branchId: string,
  staffId: string,
) {
  const settings = await manager.findOne(ShopSettings, {
    where: { branchId },
    lock: { mode: "pessimistic_read" },
  });
  if (!settings) throw new NotFoundException("Branch settings not found");
  const staff = await manager.findOne(User, {
    where: { id: staffId },
    lock: { mode: "pessimistic_write" },
  });
  if (!staff || staff.role !== "staff" || !staff.isApproved)
    throw new BadRequestException("Approved Staff required");
  if (staff.branchId !== branchId)
    throw new ForbiddenException("Staff belongs to another branch");
  return staff;
}
