import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { EntityManager, Repository } from "typeorm";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { scopedMutation, requireRole } from "../common/mutations";
import { branchScope, interval, lockCalendar } from "../common/calendar";
import { defined } from "../common/catalog-crud";
import { StaffShift } from "./staff-shift.entity";
import { CreateShiftDto, UpdateShiftDto } from "./shift.dto";
@Injectable()
export class StaffShiftsService {
  constructor(
    @InjectRepository(StaffShift)
    private readonly shifts: Repository<StaffShift>,
  ) {}
  list(branchId: string, actor: Actor) {
    branchScope(actor, branchId);
    return this.shifts.find({
      where: { branchId },
      order: { startAt: "ASC", id: "ASC" },
    });
  }
  own(actor: Actor) {
    requireRole(actor, ["staff"]);
    return this.shifts.find({
      where: { staffId: actor.id, branchId: actor.branchId! },
      order: { startAt: "ASC" },
    });
  }
  create(branchId: string, dto: CreateShiftDto, actor: Actor) {
    branchScope(actor, branchId);
    const times = interval(dto.startAt, dto.endAt);
    return scopedMutation(
      this.shifts,
      actor,
      ["manager", "superAdmin"],
      async (manager, current) => {
        branchScope({ ...current, tokenVersion: actor.tokenVersion }, branchId);
        const overlap = await manager.query(
          "SELECT EXISTS(SELECT 1 FROM staff_shifts WHERE staff_id=$1 AND start_at<$3 AND end_at>$2) AS busy",
          [dto.staffId, times.startAt, times.endAt],
        );
        if (overlap[0].busy)
          throw new ConflictException("Shift overlaps existing work");
        const row = manager.create(StaffShift, {
          id: randomUUID(),
          branchId,
          staffId: dto.staffId,
          ...times,
        });
        await manager.insert(StaffShift, row);
        return row;
      },
      async (manager) => {
        await lockCalendar(manager, branchId, dto.staffId);
      },
    );
  }
  async edit(id: string, dto: UpdateShiftDto | undefined, actor: Actor) {
    requireRole(actor, ["manager", "superAdmin"]);
    const before = await this.shifts.findOneBy({ id });
    if (!before) throw new NotFoundException("Shift not found");
    branchScope(actor, before.branchId);
    const fields = dto ? defined(dto) : undefined;
    if (fields && !Object.keys(fields).length)
      throw new BadRequestException("Empty update");
    return scopedMutation(
      this.shifts,
      actor,
      ["manager", "superAdmin"],
      async (manager, current) => {
        branchScope(
          { ...current, tokenVersion: actor.tokenVersion },
          before.branchId,
        );
        const row = await manager.findOne(StaffShift, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!row) throw new NotFoundException();
        if (row.branchId !== before.branchId || row.staffId !== before.staffId)
          throw new ConflictException("Shift identity changed");
        const busy = await manager.query(
          "SELECT EXISTS(SELECT 1 FROM appointments WHERE staff_id=$1 AND branch_id=$2 AND status IN ('pending','confirmed','completed') AND start_at<$4 AND end_at>$3) AS busy",
          [row.staffId, row.branchId, row.startAt, row.endAt],
        );
        if (busy[0].busy)
          throw new ConflictException("Shift has booked appointments");
        if (!fields) {
          await manager.delete(StaffShift, { id });
          return { message: "Shift deleted" };
        }
        const times = interval(
          fields.startAt ?? row.startAt,
          fields.endAt ?? row.endAt,
        );
        const overlap = await manager.query(
          "SELECT EXISTS(SELECT 1 FROM staff_shifts WHERE staff_id=$1 AND id<>$2 AND start_at<$4 AND end_at>$3) AS busy",
          [row.staffId, id, times.startAt, times.endAt],
        );
        if (overlap[0].busy)
          throw new ConflictException("Shift overlaps existing work");
        Object.assign(row, times);
        return manager.save(StaffShift, row);
      },
      async (manager) => {
        await lockCalendar(manager, before.branchId, before.staffId);
      },
    );
  }
}
