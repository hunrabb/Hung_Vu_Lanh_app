import {
  BadRequestException,
  ConflictException,
  Injectable,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { interval } from "../common/calendar";
import { FirestoreStore } from "../firestore/firestore.store";
import {
  blocking,
  branchScope,
  fields,
  get,
  mutation,
  overlaps,
  requireRole,
  sorted,
  staff,
} from "../firestore/rules";
import { CreateShiftDto, UpdateShiftDto } from "./shift.dto";
@Injectable()
export class StaffShiftsService {
  constructor(private readonly db: FirestoreStore) {}
  list(branchId: string, actor: Actor) {
    branchScope(actor, branchId);
    return this.db.read(["staff_shifts"], (s) =>
      sorted(
        s.staff_shifts.filter((r) => r.branchId === branchId),
        "startAt",
      ),
    );
  }
  own(actor: Actor) {
    requireRole(actor, ["staff"]);
    return this.db.read(["staff_shifts"], (s) =>
      sorted(
        s.staff_shifts.filter(
          (r) => r.staffId === actor.id && r.branchId === actor.branchId,
        ),
        "startAt",
      ),
    );
  }
  create(branchId: string, dto: CreateShiftDto, actor: Actor) {
    branchScope(actor, branchId);
    const times = interval(dto.startAt, dto.endAt);
    return mutation(
      this.db,
      ["branches", "staff_shifts"],
      actor,
      ["manager", "superAdmin"],
      (s, current) => {
        branchScope(current as Actor, branchId);
        staff(s, branchId, dto.staffId);
        if (
          s.staff_shifts.some(
            (r) => r.staffId === dto.staffId && overlaps(r, times),
          )
        )
          throw new ConflictException("Shift overlaps existing work");
        const row = {
          id: randomUUID(),
          branchId,
          staffId: dto.staffId,
          ...times,
        };
        s.staff_shifts.push(row);
        return row;
      },
    );
  }
  async edit(id: string, dto: UpdateShiftDto | undefined, actor: Actor) {
    const changes = dto ? fields(dto) : undefined;
    return mutation(
      this.db,
      ["branches", "staff_shifts", "appointments"],
      actor,
      ["manager", "superAdmin"],
      (s, current) => {
        const row = get(s, "staff_shifts", id);
        branchScope(current as Actor, row.branchId);
        staff(s, row.branchId, row.staffId);
        if (
          s.appointments.some(
            (r) =>
              r.staffId === row.staffId &&
              r.branchId === row.branchId &&
              blocking(r) &&
              overlaps(r, row),
          )
        )
          throw new ConflictException("Shift has booked appointments");
        if (!changes) {
          s.staff_shifts = s.staff_shifts.filter((r) => r.id !== id);
          return { message: "Shift deleted" };
        }
        const times = interval(
          changes.startAt ?? row.startAt,
          changes.endAt ?? row.endAt,
        );
        if (
          s.staff_shifts.some(
            (r) =>
              r.id !== id && r.staffId === row.staffId && overlaps(r, times),
          )
        )
          throw new ConflictException("Shift overlaps existing work");
        Object.assign(row, times);
        return row;
      },
    );
  }
}
