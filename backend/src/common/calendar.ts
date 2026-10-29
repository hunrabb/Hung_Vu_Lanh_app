import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import { Actor } from "../auth/auth.decorators";
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
