import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
} from "@nestjs/common";
import { UsersService } from "./users.service";
import { Actor, CurrentUser, Roles } from "../auth/auth.decorators";
import { CreateStaffDto, UpdateStaffDto, ApproveStaffDto } from "./staff.dto";

@Controller("users")
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Roles("manager") @Post("staff") create(
    @Body() dto: CreateStaffDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.users.createStaff(dto, actor);
  }
  @Roles("manager") @Patch("staff/:id") update(
    @Param("id") id: string,
    @Body() dto: UpdateStaffDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.users.updateStaff(id, dto, actor);
  }
  @Roles("boss") @HttpCode(200) @Post(":id/approve") approve(
    @Param("id") id: string,
    @Body() dto: ApproveStaffDto,
    @CurrentUser() actor: Actor,
  ) {
    return this.users.approve(id, dto.password, actor);
  }
  @Roles("boss") @Delete(":id/pending") reject(
    @Param("id") id: string,
    @CurrentUser() actor: Actor,
  ) {
    return this.users.rejectPending(id, actor);
  }

  @Get("pending")
  @Roles("boss")
  findPending(@CurrentUser() actor: Actor) {
    return this.users.findPendingStaff(actor);
  }

  @Get("branch/:branchId")
  @Roles("boss", "manager")
  findByBranch(
    @Param("branchId") branchId: string,
    @CurrentUser() actor: Actor,
  ) {
    if (!branchId.trim() || branchId.length > 200)
      throw new BadRequestException("Invalid branchId");
    return this.users.findStaffByBranch(branchId, actor);
  }
}
