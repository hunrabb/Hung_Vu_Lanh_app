import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from "@nestjs/common";
import { Actor, CurrentUser, Roles } from "../auth/auth.decorators";
import { StaffShiftsService } from "./staff-shifts.service";
import { CreateShiftDto, UpdateShiftDto } from "./shift.dto";
@Controller()
export class StaffShiftsController {
  constructor(private readonly shifts: StaffShiftsService) {}
  @Roles("boss", "manager") @Get("branches/:branchId/shifts") list(
    @Param("branchId") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.shifts.list(id, actor);
  }
  @Roles("manager", "boss") @Post("branches/:branchId/shifts") create(
    @Param("branchId") id: string,
    @Body() dto: CreateShiftDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.shifts.create(id, dto, actor);
  }
  @Roles("boss", "manager") @Patch("shifts/:id") update(
    @Param("id") id: string,
    @Body() dto: UpdateShiftDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.shifts.edit(id, dto, actor);
  }
  @Roles("boss", "manager") @Delete("shifts/:id") remove(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.shifts.edit(id, undefined, actor);
  }
  @Roles("staff") @Get("staff/me/shifts") own(@CurrentUser() actor: Actor) {
    return this.shifts.own(actor);
  }
}
