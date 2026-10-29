import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
} from "@nestjs/common";
import { Actor } from "../auth/auth.decorators";
import { FirestoreStore, Row, wire } from "../firestore/firestore.store";
import { get, mutation, page, requireRole, sorted } from "../firestore/rules";
import { AppointmentQueryDto } from "./appointment.dto";
@Injectable()
export class AppointmentsService {
  constructor(private readonly db: FirestoreStore) {}
  async list(q: AppointmentQueryDto, actor: Actor) {
    requireRole(actor, ["customer", "staff", "manager", "superAdmin"]);
    if (
      ["manager", "staff"].includes(actor.role) &&
      q.branchId &&
      q.branchId !== actor.branchId
    )
      throw new ForbiddenException("Branch access denied");
    if (q.from && q.to && new Date(q.from) >= new Date(q.to))
      throw new BadRequestException("Invalid date range");
    return this.db.read(["appointments", "users"], (s) => {
      const branch = ["manager", "staff"].includes(actor.role)
        ? actor.branchId
        : q.branchId;
      const rows = s.appointments.filter(
        (r) =>
          (!branch || r.branchId === branch) &&
          (!q.status || r.status === q.status) &&
          (!q.from || +r.startAt >= +new Date(q.from)) &&
          (!q.to || +r.startAt < +new Date(q.to)) &&
          (actor.role !== "customer" ||
            (r.customerId === actor.id && !r.isHiddenByCustomer)) &&
          (actor.role !== "staff" ||
            (r.staffId === actor.id && !r.isHiddenByStaff)),
      );
      return page(sorted(rows, "startAt", true), q).map((r) => ({
        staffName: s.users.find((u) => u.id === r.staffId)?.name ?? r.staffId,
        ...wire("appointments", r),
      }));
    });
  }
  private scope(r: Row, actor: Actor, action: string) {
    if (
      (actor.role === "superAdmin" && action === "cancel") ||
      (actor.role === "manager" && r.branchId === actor.branchId) ||
      (actor.role === "customer" &&
        r.customerId === actor.id &&
        ["cancel", "hideCustomer"].includes(action)) ||
      (actor.role === "staff" &&
        r.staffId === actor.id &&
        r.branchId === actor.branchId &&
        ["completed", "noShow", "hideStaff"].includes(action))
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
    return mutation(this.db, ["appointments"], actor, roles, (s, user) => {
      const row = get(s, "appointments", id);
      this.scope(row, user as Actor, action);
      if (action === "hideCustomer" || action === "hideStaff") {
        if (!["completed", "cancelled", "noShow"].includes(row.status))
          throw new ConflictException("Only ended appointments may be hidden");
        row[
          action === "hideCustomer" ? "isHiddenByCustomer" : "isHiddenByStaff"
        ] = true;
      } else {
        if (
          action === "cancel"
            ? !["pending", "confirmed"].includes(row.status)
            : row.status !== "confirmed"
        )
          throw new ConflictException("Invalid appointment transition");
        row.status = action === "cancel" ? "cancelled" : action;
      }
      return wire("appointments", row);
    });
  }
}
