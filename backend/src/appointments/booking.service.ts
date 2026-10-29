import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { FirestoreStore, State, wire } from "../firestore/firestore.store";
import {
  blocking,
  get,
  mutation,
  requireRole,
  sorted,
  staff,
} from "../firestore/rules";
import {
  AvailableSlotsDto,
  CreateBookingDto,
  WalkInDto,
} from "./appointment.dto";
import { calculateSlots, hanoiDay } from "./slot-engine";
export const bookingCollections = [
  "branches",
  "users",
  "services",
  "staff_shifts",
  "staff_leave_requests",
  "appointments",
] as const;
@Injectable()
export class BookingService {
  constructor(private readonly db: FirestoreStore) {}
  eligible(branchId: string, serviceId: string) {
    return this.db.read(["users", "services"], (s) => {
      const service = get(s, "services", serviceId);
      if (!service.isActive)
        throw new NotFoundException("Active service not found");
      return sorted(
        s.users.filter(
          (u) =>
            u.role === "staff" &&
            u.isApproved &&
            u.branchId === branchId &&
            u.specializedCategoryIds.includes(service.categoryId),
        ),
        "name",
      ).map(({ id, name, branchId }) => ({ id, name, branchId }));
    });
  }
  context(s: State, query: AvailableSlotsDto) {
    const day = hanoiDay(query.date),
      settings = get(s, "branches", query.branchId).settings;
    if (!settings) throw new NotFoundException("Branch settings not found");
    const person = staff(s, query.branchId, query.staffId);
    const services = query.serviceIds.map((id) => get(s, "services", id));
    if (
      !services.length ||
      new Set(query.serviceIds).size !== query.serviceIds.length ||
      services.some((r) => !r.isActive)
    )
      throw new BadRequestException("All services must be active");
    if (
      services.some(
        (r) => !person.specializedCategoryIds.includes(r.categoryId),
      )
    )
      throw new BadRequestException("Staff lacks service specialization");
    const duration = services.reduce((n, r) => n + r.durationMinutes, 0),
      price = services.reduce((n, r) => n + BigInt(r.priceVnd), 0n);
    if (duration <= 0 || duration > 1440 || price > 9223372036854775807n)
      throw new BadRequestException("Service totals exceed supported limits");
    const base = {
      services,
      totalDurationMinutes: duration,
      totalPriceVnd: price.toString(),
    };
    if (
      settings.closedDates.includes(query.date) ||
      settings.closedWeekdays.includes(day.weekday)
    )
      return { ...base, slots: [], free: [] };
    const shifts = s.staff_shifts.filter(
      (r) => r.staffId === person.id && r.branchId === query.branchId,
    );
    const busy = [
      ...s.appointments.filter((r) => blocking(r)),
      ...s.staff_leave_requests.filter((r) => r.status === "approved"),
    ].filter((r) => r.staffId === person.id);
    const span = (r: Record<string, any>) => ({
      start: +r.startAt,
      end: +r.endAt,
    });
    return {
      ...base,
      ...calculateSlots(
        {
          start: day.start + settings.openingMinute * 60000,
          end: day.start + settings.closingMinute * 60000,
        },
        shifts.map(span),
        busy.map(span),
        duration,
        Date.now(),
      ),
    };
  }
  available(query: AvailableSlotsDto) {
    return this.db.read(bookingCollections, (s) => {
      const { services, free, ...result } = this.context(s, query);
      return result;
    });
  }
  book(dto: CreateBookingDto | WalkInDto, actor: Actor, walkIn = false) {
    requireRole(actor, walkIn ? ["manager"] : ["customer"]);
    const branchId = walkIn
      ? actor.branchId
      : (dto as CreateBookingDto).branchId;
    if (!branchId) throw new ForbiddenException("Branch required");
    const startAt = new Date(dto.startAt);
    if (
      !Number.isFinite(+startAt) ||
      startAt.getUTCSeconds() !== 0 ||
      startAt.getUTCMilliseconds() !== 0
    )
      throw new BadRequestException("Booking starts on an exact minute");
    return mutation(
      this.db,
      [...bookingCollections],
      actor,
      walkIn ? ["manager"] : ["customer"],
      (s, current) => {
        if (walkIn && current.branchId !== branchId)
          throw new ForbiddenException("Branch changed");
        const context = this.context(s, {
          branchId,
          staffId: dto.staffId,
          serviceIds: dto.serviceIds,
          date: new Date(+startAt + 7 * 3600000).toISOString().slice(0, 10),
        });
        const endAt = new Date(+startAt + context.totalDurationMinutes * 60000);
        if (
          +startAt <= Date.now() ||
          !context.free.some(
            (span) => +startAt >= span.start && +endAt <= span.end,
          )
        )
          throw new ConflictException("Slot no longer available");
        const id = randomUUID(),
          row = {
            id,
            branchId,
            staffId: dto.staffId,
            customerId: walkIn ? null : current.id,
            customerName: walkIn
              ? (dto as WalkInDto).customerName
              : current.name,
            startAt,
            endAt,
            totalPriceVnd: context.totalPriceVnd,
            status: "confirmed",
            isHiddenByCustomer: false,
            isHiddenByStaff: false,
            isReviewed: false,
            rating: null,
            serviceIds: [...dto.serviceIds],
            services: dto.serviceIds.map((serviceId, position) => ({
              appointmentId: id,
              position,
              serviceId,
              serviceNameSnapshot: context.services.find(
                (r) => r.id === serviceId,
              )!.name,
            })),
          };
        s.appointments.push(row);
        return wire("appointments", row);
      },
    );
  }
}
