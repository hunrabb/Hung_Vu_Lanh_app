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
  branchScope,
  get,
  mutation,
  overlaps,
  requireRole,
  sorted,
  staff,
} from "../firestore/rules";
import { CreateLeaveDto, DecisionDto } from "./leave.dto";
@Injectable()
export class LeaveRequestsService {
  constructor(private readonly db: FirestoreStore) {}
  list(actor: Actor) {
    requireRole(actor, ["manager", "superAdmin"]);
    return this.db.read(["staff_leave_requests"], (s) =>
      sorted(
        s.staff_leave_requests.filter(
          (r) => actor.role === "superAdmin" || r.branchId === actor.branchId,
        ),
        "createdAt",
        true,
      ),
    );
  }
  own(actor: Actor) {
    requireRole(actor, ["staff"]);
    return this.db.read(["staff_leave_requests"], (s) =>
      sorted(
        s.staff_leave_requests.filter((r) => r.staffId === actor.id),
        "createdAt",
        true,
      ),
    );
  }
  create(dto: CreateLeaveDto, actor: Actor) {
    requireRole(actor, ["staff"]);
    const times = interval(dto.startAt, dto.endAt);
    const today =
      Math.floor((Date.now() + 7 * 3600000) / 86400000) * 86400000 -
      7 * 3600000;
    if (
      +times.startAt < today ||
      +times.endAt <= Date.now() ||
      !dto.reason.trim()
    )
      throw new BadRequestException(
        "Leave must start today or later with a reason",
      );
    return mutation(
      this.db,
      ["branches", "staff_leave_requests"],
      actor,
      ["staff"],
      (s, current) => {
        staff(s, current.branchId, current.id);
        if (
          s.staff_leave_requests.some(
            (r) =>
              r.staffId === current.id &&
              ["pending", "approved"].includes(r.status) &&
              overlaps(r, times),
          )
        )
          throw new ConflictException("Leave overlaps existing request");
        const row = {
          id: randomUUID(),
          staffId: current.id,
          staffName: current.name,
          branchId: current.branchId,
          leaveDate: new Date(+times.startAt + 7 * 3600000)
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
        };
        s.staff_leave_requests.push(row);
        return row;
      },
    );
  }
  async decision(id: string, dto: DecisionDto, actor: Actor) {
    return mutation(
      this.db,
      ["branches", "staff_leave_requests"],
      actor,
      ["manager", "superAdmin"],
      (s, current) => {
        const row = get(s, "staff_leave_requests", id);
        branchScope(current as Actor, row.branchId);
        if (row.status !== "pending")
          throw new ConflictException("Decision is immutable");
        if (!["approved", "rejected"].includes(dto.status))
          throw new BadRequestException("Decision required");
        Object.assign(row, {
          status: dto.status,
          reviewedBy: current.id,
          reviewedByName: current.name,
          reviewedBranchName: get(s, "branches", row.branchId).name,
          reviewedAt: new Date(),
          note: dto.note ?? "",
        });
        return row;
      },
    );
  }
  approvedOverlaps(
    staffId: string,
    branchId: string,
    startAt: Date,
    endAt: Date,
  ) {
    return this.db.read(["staff_leave_requests"], (s) =>
      s.staff_leave_requests.filter(
        (r) =>
          r.staffId === staffId &&
          r.branchId === branchId &&
          r.status === "approved" &&
          overlaps(r, { startAt, endAt }),
      ),
    );
  }
}
