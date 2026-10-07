import { Body, Controller, Get, Param, Post } from "@nestjs/common";
import { Actor, CurrentUser, Roles } from "../auth/auth.decorators";
import { LeaveRequestsService } from "./leave-requests.service";
import { CreateLeaveDto, DecisionDto } from "./leave.dto";
@Controller()
export class LeaveRequestsController {
  constructor(private readonly service: LeaveRequestsService) {}
  @Post("staff/me/leave-requests") @Roles("staff") create(
    @Body() dto: CreateLeaveDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.service.create(dto, actor);
  }
  @Get("staff/me/leave-requests") @Roles("staff") own(
    @CurrentUser() actor: Actor,
  ) {
    return this.service.own(actor);
  }
  @Get("leave-requests") @Roles("boss", "manager") list(
    @CurrentUser() actor: Actor,
  ) {
    return this.service.list(actor);
  }
  @Post("leave-requests/:id/decision") @Roles("boss", "manager") decision(
    @Param("id") id: string,
    @Body() dto: DecisionDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.service.decision(id, dto, actor);
  }
}
