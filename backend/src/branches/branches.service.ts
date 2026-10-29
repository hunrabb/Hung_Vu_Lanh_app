import {
  BadRequestException,
  ConflictException,
  Injectable,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { FirestoreStore, wire } from "../firestore/firestore.store";
import { branchScope, fields, get, mutation, sorted } from "../firestore/rules";
import {
  CreateBranchDto,
  UpdateBranchDto,
  UpdateSettingsDto,
} from "./branch.dto";
@Injectable()
export class BranchesService {
  constructor(private readonly db: FirestoreStore) {}
  findAll() {
    return this.db.read(["branches"], (s) =>
      sorted(s.branches, "name").map((r) => wire("branches", r)),
    );
  }
  async create(dto: CreateBranchDto, actor: Actor) {
    return mutation(this.db, ["branches"], actor, ["superAdmin"], (s) => {
      const id = randomUUID();
      const row = {
        id,
        ...dto,
        settings: {
          id: "settings-" + id,
          branchId: id,
          openingMinute: 480,
          closingMinute: 1200,
          closedWeekdays: [],
          closedDates: [],
        },
      };
      s.branches.push(row);
      return wire("branches", row);
    });
  }
  update(id: string, dto: UpdateBranchDto, actor: Actor) {
    const changes = fields(dto);
    return mutation(this.db, ["branches"], actor, ["superAdmin"], (s) => {
      const row = get(s, "branches", id);
      Object.assign(row, changes);
      return wire("branches", row);
    });
  }
  delete(id: string, actor: Actor) {
    return mutation(
      this.db,
      ["branches", "appointments", "staff_shifts", "staff_leave_requests"],
      actor,
      ["superAdmin"],
      (s) => {
        get(s, "branches", id);
        if (
          [
            ...s.users,
            ...s.appointments,
            ...s.staff_shifts,
            ...s.staff_leave_requests,
          ].some((r) => r.branchId === id)
        )
          throw new ConflictException("Record is referenced");
        s.branches = s.branches.filter((r) => r.id !== id);
        return { message: "Branch deleted" };
      },
    );
  }
  settings(id: string, dto: UpdateSettingsDto, actor: Actor) {
    const changes = fields(dto);
    return mutation(
      this.db,
      ["branches"],
      actor,
      ["superAdmin", "manager"],
      (s, user) => {
        branchScope(user as Actor, id);
        const row = get(s, "branches", id);
        Object.assign(row.settings, changes);
        if (row.settings.closingMinute <= row.settings.openingMinute)
          throw new BadRequestException("Closing must follow opening");
        return { ...row.settings };
      },
    );
  }
}
