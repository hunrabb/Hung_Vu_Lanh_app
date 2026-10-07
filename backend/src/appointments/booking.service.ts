import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { EntityManager, Repository } from "typeorm";
import { randomUUID } from "node:crypto";
import { Actor } from "../auth/auth.decorators";
import { requireRole, scopedMutation } from "../common/mutations";
import { lockCalendar } from "../common/calendar";
import { ShopSettings } from "../branches/shop-settings.entity";
import { User } from "../users/user.entity";
import { Service } from "../services/service.entity";
import { StaffSpecialization } from "../users/staff-specialization.entity";
import { Appointment, AppointmentServiceItem } from "./appointment.entity";
import {
  AvailableSlotsDto,
  CreateBookingDto,
  WalkInDto,
} from "./appointment.dto";
import { calculateSlots, hanoiDay } from "./slot-engine";

// Retry only aborted transactions, never an overlap or an uncertain commit.
export async function retryTransaction<T>(work: () => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++)
    try {
      return await work();
    } catch (error) {
      const code = (error as { code?: string }).code;
      if (!["40P01", "40001"].includes(code ?? "")) throw error;
      if (attempt >= 2)
        throw new ServiceUnavailableException("Calendar busy; retry shortly");
      await new Promise((resolve) =>
        setTimeout(resolve, 20 * (attempt + 1) + Math.random() * 30),
      );
    }
}
@Injectable()
export class BookingService {
  constructor(
    @InjectRepository(Appointment)
    private readonly appointments: Repository<Appointment>,
  ) {}
  async eligible(branchId: string, serviceId: string) {
    const manager = this.appointments.manager;
    const service = await manager.findOneBy(Service, {
      id: serviceId,
      isActive: true,
    });
    if (!service) throw new NotFoundException("Active service not found");
    return manager
      .getRepository(User)
      .createQueryBuilder("staff")
      .select(["staff.id", "staff.name", "staff.branchId"])
      .innerJoin(
        StaffSpecialization,
        "specialty",
        "specialty.staff_id=staff.id AND specialty.category_id=:category",
        { category: service.categoryId },
      )
      .where(
        "staff.role=:role AND staff.is_approved=true AND staff.branch_id=:branchId",
        { role: "staff", branchId },
      )
      .orderBy("staff.name", "ASC")
      .addOrderBy("staff.id", "ASC")
      .getMany();
  }
  async context(
    manager: EntityManager,
    query: AvailableSlotsDto,
    locked = false,
  ) {
    const day = hanoiDay(query.date);
    const settings = await manager.findOneBy(ShopSettings, {
      branchId: query.branchId,
    });
    if (!settings) throw new NotFoundException("Branch settings not found");
    const staff = await manager.findOneBy(User, {
      id: query.staffId,
      role: "staff",
      isApproved: true,
    });
    if (!staff || staff.branchId !== query.branchId)
      throw new BadRequestException(
        "Approved Staff of selected branch required",
      );
    const catalog = manager
      .getRepository(Service)
      .createQueryBuilder("service")
      .where("service.id IN (:...ids)", { ids: query.serviceIds })
      .orderBy("service.id", "ASC");
    if (locked) catalog.setLock("pessimistic_read");
    const services = await catalog.getMany();
    if (
      services.length !== query.serviceIds.length ||
      services.some((s) => !s.isActive)
    )
      throw new BadRequestException("All services must be active");
    const specialties = await manager.findBy(StaffSpecialization, {
      staffId: staff.id,
    });
    if (
      services.some(
        (s) => !specialties.some((link) => link.categoryId === s.categoryId),
      )
    )
      throw new BadRequestException("Staff lacks service specialization");
    const duration = services.reduce((total, s) => total + s.duration, 0),
      price = services.reduce((total, s) => total + BigInt(s.price), 0n);
    if (duration > 1440 || duration <= 0 || price > 9223372036854775807n)
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
    const shifts = await manager.query(
      "SELECT start_at,end_at FROM staff_shifts WHERE staff_id=$1 AND branch_id=$2 AND start_at<$4 AND end_at>$3",
      [staff.id, query.branchId, new Date(day.start), new Date(day.end)],
    );
    // Staff conflict deliberately spans ALL branches; a different branch cannot evade it.
    const busy = await manager.query(
      "SELECT start_at,end_at FROM appointments WHERE staff_id=$1 AND status IN ('pending','confirmed','completed') AND start_at<$3 AND end_at>$2 UNION ALL SELECT start_at,end_at FROM staff_leave_requests WHERE staff_id=$1 AND status='approved' AND start_at<$3 AND end_at>$2",
      [staff.id, new Date(day.start), new Date(day.end)],
    );
    const span = (row: { start_at: Date; end_at: Date }) => ({
      start: +new Date(row.start_at),
      end: +new Date(row.end_at),
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
    return this.appointments.manager.connection.transaction(
      "REPEATABLE READ",
      async (manager) => {
        const { services, free, ...result } = await this.context(
          manager,
          query,
        );
        return result;
      },
    );
  }
  book(dto: CreateBookingDto | WalkInDto, actor: Actor, walkIn = false) {
    requireRole(actor, walkIn ? ["manager"] : ["customer"]);
    const branchId = walkIn
      ? actor.branchId!
      : (dto as CreateBookingDto).branchId;
    if (!branchId) throw new ForbiddenException("Branch required");
    const startAt = new Date(dto.startAt);
    if (
      !Number.isFinite(+startAt) ||
      startAt.getUTCSeconds() !== 0 ||
      startAt.getUTCMilliseconds() !== 0
    )
      throw new BadRequestException("Booking starts on an exact minute");
    const date = new Date(+startAt + 7 * 3600000).toISOString().slice(0, 10);
    return retryTransaction(() =>
      scopedMutation(
        this.appointments,
        actor,
        walkIn ? ["manager"] : ["customer"],
        async (manager, current) => {
          if (walkIn && current.branchId !== branchId)
            throw new ForbiddenException("Branch changed");
          const context = await this.context(
            manager,
            {
              branchId,
              staffId: dto.staffId,
              serviceIds: dto.serviceIds,
              date,
            },
            true,
          );
          const endAt = new Date(
            +startAt + context.totalDurationMinutes * 60000,
          );
          // Validate continuous containment, not a stale GET slot grid (busy grid may change).
          if (
            +startAt <= Date.now() ||
            !context.free.some(
              (span) => +startAt >= span.start && +endAt <= span.end,
            )
          )
            throw new ConflictException("Slot no longer available");
          const appointment = manager.create(Appointment, {
            id: randomUUID(),
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
          });
          await manager.insert(Appointment, appointment);
          const items = dto.serviceIds.map((id, position) => ({
            appointmentId: appointment.id,
            position,
            serviceId: id,
            serviceNameSnapshot: context.services.find((s) => s.id === id)!
              .name,
          }));
          await manager.insert(AppointmentServiceItem, items);
          return { ...appointment, services: items };
        },
        async (manager) => {
          await lockCalendar(manager, branchId, dto.staffId);
        },
      ),
    );
  }
}
