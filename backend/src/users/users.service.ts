import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from "@nestjs/common";
import { Actor } from "../auth/auth.decorators";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { User } from "./user.entity";
import { randomUUID } from "node:crypto";
import { Credential } from "../auth/credential.entity";
import { hashPassword, validateNewPassword } from "../auth/passwords";
import { requireRole, scopedMutation } from "../common/mutations";
import { CreateStaffDto, UpdateStaffDto } from "./staff.dto";
import { StaffSpecialization } from "./staff-specialization.entity";
import { defined } from "../common/catalog-crud";

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
  ) {}

  createStaff(dto: CreateStaffDto, actor: Actor) {
    return scopedMutation(
      this.users,
      actor,
      ["manager"],
      async (manager, current) => {
        if (!current.branchId) throw new ForbiddenException();
        const staff = manager.create(User, {
          id: randomUUID(),
          name: dto.name,
          email: dto.email,
          phone: dto.phone,
          address: dto.address,
          role: "staff",
          isApproved: false,
          branchId: current.branchId,
          createdAt: new Date(),
        });
        await manager.insert(User, staff);
        await manager.insert(
          StaffSpecialization,
          dto.specializedCategoryIds.map((categoryId) => ({
            staffId: staff.id,
            categoryId,
          })),
        );
        return { ...staff, specializedCategoryIds: dto.specializedCategoryIds };
      },
    );
  }

  updateStaff(id: string, dto: UpdateStaffDto, actor: Actor) {
    const update = defined(dto);
    if (Object.keys(update).length === 0)
      throw new BadRequestException("Empty update");
    return scopedMutation(
      this.users,
      actor,
      ["manager"],
      async (manager, current) => {
        const staff = await manager.findOne(User, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!staff || staff.role !== "staff")
          throw new NotFoundException("Staff not found");
        if (staff.branchId !== current.branchId)
          throw new ForbiddenException("Branch access denied");
        const { specializedCategoryIds, ...fields } = update;
        Object.assign(staff, fields);
        await manager.save(User, staff);
        if (specializedCategoryIds !== undefined) {
          await manager.delete(StaffSpecialization, { staffId: id });
          await manager.insert(
            StaffSpecialization,
            specializedCategoryIds.map((categoryId) => ({
              staffId: id,
              categoryId,
            })),
          );
        }
        const links = await manager.findBy(StaffSpecialization, {
          staffId: id,
        });
        return {
          ...staff,
          specializedCategoryIds: links.map((s) => s.categoryId).sort(),
        };
      },
    );
  }

  async approve(id: string, password: string, actor: Actor) {
    requireRole(actor, ["superAdmin"]);
    validateNewPassword(password);
    const hash = await hashPassword(password);
    return scopedMutation(
      this.users,
      actor,
      ["superAdmin"],
      async (manager) => {
        const staff = await manager.findOne(User, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!staff || staff.role !== "staff")
          throw new NotFoundException("Staff not found");
        if (
          staff.isApproved ||
          (await manager.existsBy(Credential, { userId: id }))
        )
          throw new ConflictException(
            "Staff is not pending or already has credentials",
          );
        await manager.insert(Credential, {
          userId: id,
          passwordHash: hash,
          tokenVersion: 0,
        });
        await manager.update(User, { id }, { isApproved: true });
        return { ...staff, isApproved: true };
      },
    );
  }

  rejectPending(id: string, actor: Actor) {
    return scopedMutation(
      this.users,
      actor,
      ["superAdmin"],
      async (manager) => {
        const staff = await manager.findOne(User, {
          where: { id },
          lock: { mode: "pessimistic_write" },
        });
        if (!staff || staff.role !== "staff")
          throw new NotFoundException("Staff not found");
        if (
          staff.isApproved ||
          (await manager.existsBy(Credential, { userId: id }))
        )
          throw new ConflictException(
            "Only pending Staff without credentials may be rejected",
          );
        const rows = await manager.query(
          "SELECT EXISTS(SELECT 1 FROM appointments WHERE staff_id=$1) OR EXISTS(SELECT 1 FROM staff_shifts WHERE staff_id=$1) OR EXISTS(SELECT 1 FROM staff_leave_requests WHERE staff_id=$1) AS referenced",
          [id],
        );
        if (rows[0].referenced)
          throw new ConflictException(
            "Staff has appointments, shifts or leave history",
          );
        await manager.delete(User, { id });
        return { message: "Pending profile deleted" };
      },
    );
  }

  findPendingStaff(actor: Actor): Promise<User[]> {
    if (actor?.role !== "superAdmin") throw new ForbiddenException();
    return this.users.find({
      where: { role: "staff", isApproved: false },
      order: { createdAt: "ASC", id: "ASC" },
    });
  }

  findStaffByBranch(branchId: string, actor: Actor): Promise<User[]> {
    if (
      actor?.role !== "superAdmin" &&
      !(actor?.role === "manager" && actor.branchId === branchId)
    )
      throw new ForbiddenException("Branch access denied");
    return this.users.find({
      where: { role: "staff", branchId },
      order: { name: "ASC", id: "ASC" },
    });
  }
}
