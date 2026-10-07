import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { In, Repository } from "typeorm";
import { Actor } from "../auth/auth.decorators";
import { requireRole, scopedMutation } from "../common/mutations";
import { ShopSettings } from "../branches/shop-settings.entity";
import { User } from "../users/user.entity";
import {
  Appointment,
  AppointmentServiceItem,
  AppointmentStatus,
} from "./appointment.entity";
import { AppointmentQueryDto } from "./appointment.dto";
import { retryTransaction } from "./booking.service";
@Injectable()
export class AppointmentsService {
  constructor(
    @InjectRepository(Appointment)
    private readonly appointments: Repository<Appointment>,
  ) {}
  async list(query: AppointmentQueryDto, actor: Actor) {
    requireRole(actor, ["customer", "staff", "manager", "superAdmin"]);
    if (
      (actor.role === "manager" || actor.role === "staff") &&
      query.branchId &&
      query.branchId !== actor.branchId
    )
      throw new ForbiddenException("Branch access denied");
    if (query.from && query.to && new Date(query.from) >= new Date(query.to))
      throw new BadRequestException("Invalid date range");
    const q = this.appointments.createQueryBuilder("a");
    if (actor.role === "customer")
      q.andWhere("a.customer_id=:owner AND a.is_hidden_by_customer=false", {
        owner: actor.id,
      });
    if (actor.role === "staff")
      q.andWhere("a.staff_id=:owner AND a.is_hidden_by_staff=false", {
        owner: actor.id,
      });
    const branchId =
      actor.role === "manager" || actor.role === "staff"
        ? actor.branchId
        : query.branchId;
    if (branchId) q.andWhere("a.branch_id=:branchId", { branchId });
    if (query.status) q.andWhere("a.status=:status", { status: query.status });
    if (query.from) q.andWhere("a.start_at>=:from", { from: query.from });
    if (query.to) q.andWhere("a.start_at<:to", { to: query.to });
    const rows = await q
      .orderBy("a.start_at", "DESC")
      .addOrderBy("a.id", "ASC")
      .skip((query.page - 1) * query.limit)
      .take(query.limit)
      .getMany();
    const items = rows.length
      ? await this.appointments.manager.find(AppointmentServiceItem, {
          where: { appointmentId: In(rows.map((r) => r.id)) },
          order: { position: "ASC" },
        })
      : [];
    return rows.map((row) => ({
      ...row,
      services: items.filter((item) => item.appointmentId === row.id),
    }));
  }
  private scope(row: Appointment, actor: Actor, action: string) {
    if (actor.role === "superAdmin" && action === "cancel") return;
    if (actor.role === "manager" && row.branchId === actor.branchId) return;
    if (
      actor.role === "customer" &&
      row.customerId === actor.id &&
      ["cancel", "hideCustomer"].includes(action)
    )
      return;
    if (
      actor.role === "staff" &&
      row.staffId === actor.id &&
      row.branchId === actor.branchId &&
      ["completed", "noShow", "hideStaff"].includes(action)
    )
      return;
    throw new ForbiddenException("Appointment access denied");
  }
  async act(
    id: string,
    action: "cancel" | "completed" | "noShow" | "hideCustomer" | "hideStaff",
    actor: Actor,
  ) {
    const roles =
      action === "cancel"
        ? (["customer", "manager", "superAdmin"] as const)
        : action === "hideCustomer"
          ? (["customer"] as const)
          : action === "hideStaff"
            ? (["staff"] as const)
            : (["manager", "staff"] as const);
    requireRole(actor, [...roles]);
    const before = await this.appointments.findOneBy({ id });
    if (!before) throw new NotFoundException("Appointment not found");
    this.scope(before, actor, action);
    return retryTransaction(() =>
      scopedMutation(
        this.appointments,
        actor,
        [...roles],
        async (manager, current) => {
          const row = await manager.findOne(Appointment, {
            where: { id },
            lock: { mode: "pessimistic_write" },
          });
          if (!row) throw new NotFoundException();
          if (
            row.branchId !== before.branchId ||
            row.staffId !== before.staffId
          )
            throw new ConflictException("Appointment identity changed");
          this.scope(
            row,
            { ...current, tokenVersion: actor.tokenVersion },
            action,
          );
          if (action === "hideCustomer" || action === "hideStaff") {
            if (!["completed", "cancelled", "noShow"].includes(row.status))
              throw new ConflictException(
                "Only ended appointments may be hidden",
              );
            if (action === "hideCustomer") row.isHiddenByCustomer = true;
            else row.isHiddenByStaff = true;
          } else {
            if (
              action === "cancel"
                ? !["pending", "confirmed"].includes(row.status)
                : row.status !== "confirmed"
            )
              throw new ConflictException("Invalid appointment transition");
            row.status = action === "cancel" ? "cancelled" : action;
          }
          return manager.save(Appointment, row);
        },
        async (manager) => {
          // Historical Staff can move branch; lock identity without rewriting its snapshot.
          await manager.findOne(ShopSettings, {
            where: { branchId: before.branchId },
            lock: { mode: "pessimistic_read" },
          });
          await manager.findOne(User, {
            where: { id: before.staffId },
            lock: { mode: "pessimistic_write" },
          });
        },
      ),
    );
  }
}
