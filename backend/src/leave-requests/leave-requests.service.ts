import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { branchScope, interval, lockCalendar } from "../common/calendar";
import { requireRole, scopedMutation } from "../common/mutations";
import { LeaveRequest } from "./leave-request.entity";
import { CreateLeaveDto, DecisionDto } from "./leave.dto";
@Injectable()
export class LeaveRequestsService {
  constructor(
    @InjectRepository(LeaveRequest)
    private readonly requests: Repository<LeaveRequest>,
  ) {}
  list(actor: Actor) {
    requireRole(actor, ["manager", "superAdmin"]);
    return this.requests.find({
      where: actor.role === "manager" ? { branchId: actor.branchId! } : {},
      order: { createdAt: "DESC", id: "ASC" },
    });
  }
  own(actor: Actor) {
    requireRole(actor, ["staff"]);
    return this.requests.find({
      where: { staffId: actor.id },
      order: { createdAt: "DESC" },
    });
  }
  create(dto: CreateLeaveDto, actor: Actor) {
    requireRole(actor, ["staff"]);
    const times = interval(dto.startAt, dto.endAt);
    const today =
      Math.floor((Date.now() + 7 * 3600000) / 86400000) * 86400000 -
      7 * 3600000;
    if (times.startAt.getTime() < today || times.endAt.getTime() <= Date.now())
      throw new BadRequestException("Leave must start today or later");
    return scopedMutation(
      this.requests,
      actor,
      ["staff"],
      async (manager, current) => {
        const row = manager.create(LeaveRequest, {
          id: randomUUID(),
          staffId: current.id,
          staffName: current.name,
          branchId: current.branchId!,
          leaveDate: new Date(times.startAt.getTime() + 7 * 3600000)
            .toISOString()
            .slice(0, 10),
          ...times,
          reason: dto.reason,
          createdAt: new Date(),
          status: "pending",
          reviewedBy: null,
          reviewedByName: null,
          reviewedBranchName: null,
          reviewedAt: null,
          note: "",
        });
        await manager.insert(LeaveRequest, row);
        return row;
      },
      async (manager) => {
        await lockCalendar(manager, actor.branchId!, actor.id);
      },
    );
  }
  async decision(id: string, dto: DecisionDto, actor: Actor) {
    requireRole(actor, ["manager", "superAdmin"]);
    const before = await this.requests.findOneBy({ id });
    if (!before) throw new NotFoundException("Leave request not found");
    branchScope(actor, before.branchId);
    return scopedMutation(
      this.requests,
      actor,
      ["manager", "superAdmin"],
      async (manager, current) => {
        branchScope(
          { ...current, tokenVersion: actor.tokenVersion },
          before.branchId,
        );
        const row = await manager.findOne(LeaveRequest, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!row) throw new NotFoundException();
        if (row.status !== "pending")
          throw new ConflictException("Decision is immutable");
        if (row.staffId !== before.staffId || row.branchId !== before.branchId)
          throw new ConflictException("Request identity changed");
        await manager.update(
          LeaveRequest,
          { id },
          { status: dto.status, reviewedBy: current.id, note: dto.note ?? "" },
        );
        return manager.findOneByOrFail(LeaveRequest, { id });
      },
      async (manager) => {
        await lockCalendar(manager, before.branchId, before.staffId);
      },
    );
  }
  approvedOverlaps(
    staffId: string,
    branchId: string,
    startAt: Date,
    endAt: Date,
  ) {
    return this.requests
      .createQueryBuilder("leave")
      .where(
        "leave.staff_id=:staffId AND leave.branch_id=:branchId AND leave.status=:status AND leave.start_at<:endAt AND leave.end_at>:startAt",
        { staffId, branchId, status: "approved", startAt, endAt },
      )
      .getMany();
  }
}
