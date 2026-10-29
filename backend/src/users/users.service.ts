import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { FirestoreStore } from "../firestore/firestore.store";
import {
  branchScope,
  emailUnique,
  fields,
  get,
  mutation,
  requireRole,
  sorted,
} from "../firestore/rules";
import { hashPassword, validateNewPassword } from "../auth/passwords";
import { CreateStaffDto, UpdateStaffDto } from "./staff.dto";
@Injectable()
export class UsersService {
  constructor(private readonly db: FirestoreStore) {}
  async createStaff(dto: CreateStaffDto, actor: Actor) {
    return mutation(
      this.db,
      ["branches", "categories"],
      actor,
      ["manager"],
      (s, current) => {
        if (!current.branchId) throw new ForbiddenException();
        get(s, "branches", current.branchId);
        emailUnique(s, dto.email);
        dto.specializedCategoryIds.forEach((id) => get(s, "categories", id));
        const row = {
          id: randomUUID(),
          ...dto,
          email: dto.email.trim().toLowerCase(),
          specializedCategoryIds: [...dto.specializedCategoryIds].sort(),
          role: "staff",
          isApproved: false,
          branchId: current.branchId,
          createdAt: new Date(),
        };
        s.users.push(row);
        return { ...row };
      },
    );
  }
  updateStaff(id: string, dto: UpdateStaffDto, actor: Actor) {
    const changes = fields(dto);
    return mutation(
      this.db,
      ["categories"],
      actor,
      ["manager"],
      (s, current) => {
        const row = get(s, "users", id);
        if (row.role !== "staff")
          throw new NotFoundException("Staff not found");
        branchScope(current as Actor, row.branchId);
        if (changes.email) {
          emailUnique(s, changes.email, id);
          changes.email = changes.email.trim().toLowerCase();
        }
        if (changes.specializedCategoryIds)
          changes.specializedCategoryIds.forEach((id: string) =>
            get(s, "categories", id),
          );
        Object.assign(row, changes);
        row.specializedCategoryIds = [...row.specializedCategoryIds].sort();
        return { ...row };
      },
    );
  }
  async approve(id: string, password: string, actor: Actor) {
    requireRole(actor, ["superAdmin"]);
    validateNewPassword(password);
    const hash = await hashPassword(password);
    return mutation(this.db, [], actor, ["superAdmin"], (s) => {
      const row = get(s, "users", id);
      if (row.role !== "staff") throw new NotFoundException("Staff not found");
      if (row.isApproved || s.auth_credentials.some((c) => c.userId === id))
        throw new ConflictException(
          "Staff is not pending or already has credentials",
        );
      s.auth_credentials.push({
        userId: id,
        passwordHash: hash,
        tokenVersion: 0,
      });
      row.isApproved = true;
      return { ...row };
    });
  }
  rejectPending(id: string, actor: Actor) {
    return mutation(
      this.db,
      ["appointments", "staff_shifts", "staff_leave_requests"],
      actor,
      ["superAdmin"],
      (s) => {
        const row = get(s, "users", id);
        if (
          row.role !== "staff" ||
          row.isApproved ||
          s.auth_credentials.some((c) => c.userId === id)
        )
          throw new ConflictException(
            "Only pending Staff without credentials may be rejected",
          );
        if (
          [
            ...s.appointments,
            ...s.staff_shifts,
            ...s.staff_leave_requests,
          ].some((r) => r.staffId === id)
        )
          throw new ConflictException(
            "Staff has appointments, shifts or leave history",
          );
        s.users = s.users.filter((u) => u.id !== id);
        return { message: "Pending profile deleted" };
      },
    );
  }
  findPendingStaff(actor: Actor) {
    requireRole(actor, ["superAdmin"]);
    return this.db.read(["users"], (s) =>
      sorted(
        s.users.filter((u) => u.role === "staff" && !u.isApproved),
        "createdAt",
      ),
    );
  }
  findStaffByBranch(id: string, actor: Actor) {
    branchScope(actor, id);
    return this.db.read(["users"], (s) =>
      sorted(
        s.users.filter((u) => u.role === "staff" && u.branchId === id),
        "name",
      ),
    );
  }
}
