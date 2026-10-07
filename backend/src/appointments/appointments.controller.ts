import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";
import { Actor, CurrentUser, Public, Roles } from "../auth/auth.decorators";
import {
  AppointmentQueryDto,
  AvailableSlotsDto,
  CreateBookingDto,
  EligibleStaffDto,
  WalkInDto,
} from "./appointment.dto";
import { BookingService } from "./booking.service";
import { AppointmentsService } from "./appointments.service";
@Controller()
export class AppointmentsController {
  constructor(
    private readonly booking: BookingService,
    private readonly appointments: AppointmentsService,
  ) {}
  @Public() @Get("branches/:branchId/staff") eligible(
    @Param("branchId") branchId: string,
    @Query() query: EligibleStaffDto,
  ) {
    return this.booking.eligible(branchId, query.serviceId);
  }
  @Public() @Get("booking/available-slots") slots(
    @Query() query: AvailableSlotsDto,
  ) {
    return this.booking.available(query);
  }
  @Roles("customer") @Post("appointments") create(
    @Body() dto: CreateBookingDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.booking.book(dto, actor);
  }
  @Roles("manager") @Post("appointments/walk-in") walkIn(
    @Body() dto: WalkInDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.booking.book(dto, actor, true);
  }
  @Get("appointments") list(
    @Query() query: AppointmentQueryDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.appointments.list(query, actor);
  }
  @Roles("customer", "manager", "boss") @Post("appointments/:id/cancel") cancel(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.appointments.act(id, "cancel", actor);
  }
  @Roles("manager", "staff") @Post("appointments/:id/complete") complete(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.appointments.act(id, "completed", actor);
  }
  @Roles("manager", "staff") @Post("appointments/:id/no-show") noShow(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.appointments.act(id, "noShow", actor);
  }
  @Roles("customer") @Post("appointments/:id/hide/customer") hideCustomer(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.appointments.act(id, "hideCustomer", actor);
  }
  @Roles("staff") @Post("appointments/:id/hide/staff") hideStaff(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.appointments.act(id, "hideStaff", actor);
  }
}
